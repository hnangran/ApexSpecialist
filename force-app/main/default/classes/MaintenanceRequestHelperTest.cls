@isTest
public with sharing class MaintenanceRequestHelperTest {

    //create test data in the following way:
    //1. Create Product2 records with Maintenance_Cycle__c values
    //2. Create Case records of type Repair or Routine Maintenance with status Open
    //3. Create Equipment_Maintenance_Item__c records linking to Product2 records
    //4. Update Case records to status Closed to trigger the logic
    //5. Verify that new Case records of type Routine Maintenance are created with correct due dates
    //6. Test bulk processing by creating and closing multiple Case records at once


    @TestSetup
    static void setupTestData(){
        List<Product2> products = new List<Product2>(); 
        for(Integer i=1; i<=5; i++){
            products.add(new Product2(Name='Equipment '+i, Maintenance_Cycle__c=30*i, IsActive=true, Replacement_Part__c=true));
        }
        //debug statement to see created products
        System.debug('In Test Class: Created Products: ' + products);
        insert products;
        //debug statement to confirm insertion
        System.debug('In Test Class: Inserted Products: ' + products);

        //insert cases and link an equipment to each case
        List<Case> cases = new List<Case>();
        for(Integer i=1; i<=5; i++){
            cases.add(new Case(Status='Open', Type=(Math.mod(i,2)==0)?'Routine Maintenance':'Repair', Subject='Maintenance Request '+i, ProductID=products[i-1].Id));
        }
        //debug statement to see created cases
        System.debug('In Test Class: Created Cases: ' + cases);
        insert cases;
        //debug statement to confirm insertion
        System.debug('In Test Class: Inserted Cases: ' + cases);

        List<Equipment_Maintenance_Item__c> emItems = new List<Equipment_Maintenance_Item__c>();
        for(Integer i=0; i<cases.size(); i++){
            emItems.add(new Equipment_Maintenance_Item__c(Maintenance_Request__c=cases[i].Id, Equipment__c=products[i].Id));
        }
        //debug statement to see created equipment maintenance items
        System.debug('In Test Class: Created Equipment Maintenance Items: ' + emItems);
        insert emItems;
        //debug statement to confirm insertion
        System.debug('In Test Class: Inserted Equipment Maintenance Items: ' + emItems);
/*
        cases[0].Status='Closed';
        //debug statement to see case before update
        System.debug('Case to be closed: ' + cases[0].id);
        update cases;
        //debug statement to confirm update
        System.debug('Updated Case: ' + cases[0].id);
        */
    }

    @isTest
    static void testSingleRecordClosure(){
        Case c = [SELECT Id, Status, productID, parentId, CreatedDate FROM Case WHERE Status='Open' LIMIT 1];
        //debug statement to see case before update
        System.debug('In Test Class: Case to be closed: ' + c);
        c.Status='Closed';
        Test.startTest();
        update c;
        //debug statement to see case after status change
        System.debug('In Test Class: Case after status change: ' + c);
        Test.stopTest();

/*        
        //add a delay to ensure the after trigger processing is complete
        Long startTime = DateTime.now().getTime();
        Long delayMillis = 5000; // 5 seconds
        while (DateTime.now().getTime() - startTime < delayMillis) {
            // Do nothing, just wait
        }
*/
        List<Case> newCases = [SELECT Id, ProductId, Type, Date_Due__c, Date_Reported__c, parentID, CreatedDate FROM Case WHERE Status= 'New' ORDER BY CreatedDate DESC LIMIT 1];
        //debug statement to see newly created cases
        System.debug('In Test Class: Newly created Routine Maintenance Cases: ' + newCases);
        System.assert(newCases.size() > 0, 'A new Routine Maintenance case should be created');
        Case newCase = newCases[0];

        //debug statement to see newly created case
        System.debug('In Test Class: Newly created Routine Maintenance Case: ' + newCase);
        //debug statement to see old case
        System.debug('In Test Class: Old Case: ' + c);
        //debug statement to compare the Equipment for the new and closed requests
        System.debug('In Test Class Comparison of Equipment:');
        //debug statement to verify that the new and old equipments are related via parentID
        System.debug('In Test Class: New case Parent ID: ' + newCase.parentId);
        System.debug('In Test Class: Old case ID: ' + c.Id);
        System.debug('In Test Class: New Case Equipment: ' + newCase.ProductId);
        System.debug('In Test Class: Closed Case Equipment: ' + c.ProductId);

        System.assertEquals(c.productId, newCase.productID, 'The challenge is expecting the new Maintenance Request to be joined to the same Equipment as the closed Maintenance Request');
        System.assertNotEquals(null, newCase.Date_Due__c, 'Due date should be set');
    }

    @isTest
    static void testBulkRecordClosure(){
        List<Case> casesToClose = [SELECT Id, Status, productID FROM Case WHERE Status='Open'];
        //debug statement to see cases before update
        System.debug('In Test Class: Cases to be closed: ' + casesToClose);
        
        for(Case c : casesToClose){
            c.Status='Closed';  
        }
        Test.startTest();
        update casesToClose;
        Test.stopTest();
        //debug statement to see cases after status change
        System.debug('In Test Class: Cases after status change: ' + casesToClose);

        List<Case> newCases = [SELECT Id, Type, Date_Due__c, Date_Reported__c FROM Case WHERE Type='Routine Maintenance' AND Date_Reported__c=TODAY ORDER BY CreatedDate DESC LIMIT :casesToClose.size()];
        //debug statement to see newly created cases
        System.debug('In Test Class: Newly created Routine Maintenance Cases: ' + newCases);
        System.assertEquals(casesToClose.size(), newCases.size(), 'New Routine Maintenance cases should be created for each closed case');
    }
} 