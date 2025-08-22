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
@isTest
private class MaintenanceRequestTest {

    /*
    This is a test class for the MaintenanceRequest Trigger
    */

    @isTest
    static void testMaintenanceRequestTrigger() {
        //Create maintenance requests that will trigger the MaintenanceRequest trigger
        List<Case> testCases = new List<Case>();
        //method to create maintenance requests and return the list of cases
        testCases = createMaintenanceRequests();

        //Create equipments with random maintenance cycles
        List<Equipment__c> testEquipments = new List<Equipment__c>();
        //method to create equipments and return the list of equipments
        testEquipments = createEquipments();

        //Create maintenance items
        List<Equipment_Maintenance_Item__c> testMaintenanceItems = new List<Equipment_Maintenance_Item__c>();
        //method to create maintenance items and return the list of maintenance items
        testMaintenanceItems = createMaintenanceItems(testCases, testEquipments);

        //Update the cases to trigger the MaintenanceRequest trigger and randomly set status to Closed
        Test.startTest();
            updateMaintenanceRequestStatus(testCases);
        Test.stopTest();
    }

    private static List<Case> createMaintenanceRequests() {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 5; i++) {
            Case newCase = new Case(
                Subject = 'Maintenance Request ' + i,
                Status = 'New',
                Origin = 'Phone',
                Type = 'Maintenance Request'
            );
            cases.add(newCase);
        }
        insert cases;
        return cases;
    }
    private static List<Equipment__c> createEquipments() {
        List<Equipment__c> equipments = new List<Equipment__c>();
        for (Integer i = 0; i < 5; i++) {
            Equipment__c newEquipment = new Equipment__c(
                Name = 'Equipment ' + i,
                Serial_Number__c = 'SN' + i,
                maintenance_Cycle__c = Math.mod(i, 3) + 1, // Random maintenance cycle between 1 and 3
                Status__c = 'Active'
            );
            equipments.add(newEquipment);
        }
        insert equipments;
        return equipments;
    }
    
    private static List<Equipment_Maintenance_Item__c> createMaintenanceItems(List<Case> cases, List<Equipment__c> equipments) {
        List<Equipment_Maintenance_Item__c> maintenanceItems = new List<Equipment_Maintenance_Item__c>();
        for (Integer i = 0; i < cases.size(); i++) {
            Equipment_Maintenance_Item__c newItem = new Equipment_Maintenance_Item__c(
                Name = 'Maintenance Item ' + i,
                Equipment__c = equipments[Math.mod(i, cases.size())].Id,
                Maintenance_Request__c = cases[Math.mod(i, cases.size())].Id,
                Status__c = 'Pending',
                Scheduled_Date__c = System.today().addDays(i)
            );
            maintenanceItems.add(newItem);  
        }
        insert maintenanceItems;
        return maintenanceItems;    
    }

    private static void updateMaintenanceRequestStatus(List<Case> cases) {
        for (Case c : cases) {
            c.Status = 'Closed';
        }
        update cases;
    }
}