/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
/*
 * This is a test class for class WarehouseCalloutService created for the the challenge: Warehouse Callout Service
 * 1. Create a class that implements the Queueable interface to perform a callout to an external warehouse system. 
 * 2. The callout should retrieve a list of equipment records in JSON format.
 * 3. Parse the JSON response and map the fields to the corresponding Salesforce Product2 fields.
 * 4. Use the Warehouse SKU as the external ID to upsert the equipment records in Salesforce.
 * 5. Ensure that the callout is made asynchronously using the Queueable interface.
 * 6. Include error handling to manage callout failures and log appropriate messages.   
 * 7. Add debug statements to log the response and any errors encountered during the callout.
 * 8. Write a unit test to cover the callout logic and ensure at least 75% code coverage.
 * Note: Since callouts cannot be made from test methods, use the Test.setMock method to simulate
 * the callout response in your unit test.
 */

@isTest
private class WarehouseCalloutServiceTest {

    @IsTest
    static void testWarehouseCallout(){
        Test.startTest();   // Start test
        Test.setMock(HttpCalloutMock.class, new WarehouseCalloutServiceMock()); // Set mock callout class
        // Enqueue the Queueable class
        ID jobID = System.enqueueJob(new WarehouseCalloutService());
        Test.stopTest();    // End test, this will also execute the queued job  

        // Verify that the job was enqueued
        System.assertNotEquals(null, jobID, 'The job ID should not be null');

        // Verify that the Product2 records were upserted
        List<Product2> products = [SELECT Id, Replacement_Part__c, Cost__c, Current_Inventory__c, Lifespan_Months__c, Maintenance_Cycle__c, Warehouse_SKU__c FROM Product2 WHERE Warehouse_SKU__c IN ('SKU123', 'SKU456', 'SKU789')];
        System.assertEquals(3, products.size(), 'Three products should have been upserted');
        for(Product2 p : products){
            System.assertEquals(true, p.Replacement_Part__c, 'Replacement_Part__c should be true');
            System.assertNotEquals(null, p.Cost__c, 'Cost__c should not be null');
            System.assertNotEquals(null, p.Current_Inventory__c, 'Current_Inventory__c should not be null');
            System.assertNotEquals(null, p.Lifespan_Months__c, 'Lifespan_Months__c should not be null');
            System.assertNotEquals(null, p.Maintenance_Cycle__c, 'Maintenance_Cycle__c should not be null');
        }   
    }

    /* 
        Mock class to simulate the HTTP callout response
        Returns a predefined JSON response for testing purposes:
            String Id;
            boolean replacement;
            Integer quantity;
            String name;
            Integer maintenanceperiod;
            Integer lifespan;
            Decimal cost;
            String sku;
    */
    private class WarehouseCalloutServiceMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[{"id":"1","replacement":true,"quantity":100,"name":"Equipment A","maintenanceperiod":30,"lifespan":12,"cost":500.00,"sku":"SKU123"},'+
                            '{"id":"2","replacement":true,"quantity":200,"name":"Equipment B","maintenanceperiod":60,"lifespan":24,"cost":1500.00,"sku":"SKU456"},'+
                            '{"id":"3","replacement":true,"quantity":150,"name":"Equipment C","maintenanceperiod":90,"lifespan":36,"cost":2500.00,"sku":"SKU789"}]');
            res.setStatusCode(200);
            return res; 
        }
    }

}