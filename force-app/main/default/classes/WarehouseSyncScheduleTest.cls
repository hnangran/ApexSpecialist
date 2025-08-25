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
@IsTest
private class WarehouseSyncScheduleTest {

    @IsTest static void schedulesAndRunsQueueable() {
        // Ensure callout succeeds when the scheduled job enqueues the queueable
        Test.setMock(HttpCalloutMock.class, new WarehouseCalloutServiceMock());

        Test.startTest();
        // Any valid cron works in tests; this means 2:00 AM daily
        String cron = '0 0 2 * * ?';
        System.schedule('Warehouse Daily Sync', cron, new WarehouseSyncSchedule());
        Test.stopTest(); // executes the scheduled job and the enqueued queueable

        // Assert that the queueable upserted records (adjust fields/object names if needed)
        List<Product2> products = [SELECT Id, Replacement_Part__c, Cost__c, Current_Inventory__c, Lifespan_Months__c, Maintenance_Cycle__c, Warehouse_SKU__c FROM Product2 WHERE Warehouse_SKU__c IN ('SKU123', 'SKU456', 'SKU789')];
        System.assertEquals(3, products.size(), 'Three products should have been upserted');
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