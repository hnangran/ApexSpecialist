public with sharing class MaintenanceRequestHelper {
    
    /* Application logic for maintenance request trigger:
        1. When an existing maintenance request of type Repair or Routine Maintenance is closed, create a new maintenance request for a future routine checkup. 
        2. This new maintenance request is tied to the same Vehicle and Equipment Records as the original closed request. 
        3. For record keeping purposes the existing equipment maintenance items must remain tied to the original close request so new records must be created. 
        4. This new request's Type should be set as Routine Maintenance. 
        5. The Subject should not be null and the Report Date field reflects the day the request was created. 
        6. Remember, all equipment has maintenance cycles.
        7. Calculate the maintenance request due dates by using the maintenance cycle defined on the related equipment records. 
        8. If multiple pieces of equipment are used in the maintenance request, define the due date by applying the shortest maintenance cycle to today’s date.
        9. Design the code to work for both single and bulk maintenance requests. 
        10. Bulkify the system to successfully process approximately 300 records of offline maintenance requests that are scheduled to import together. 
    */
    public static void updateWorkOrders(List<Case> maintenanceRequests, Map<Id, Case> oldMap) {

        //Debug statement to see incoming maintenance requests and old map
        System.debug('In Helper Class: Incoming Maintenance Requests: ' + maintenanceRequests);
        System.debug('In Helper Class: Old Map: ' + oldMap);

        // Step 1 - find existing maintenance request of type Repair or Routine Maintenance and status changes from not closed to closed
        List<Case> closedRequests = new List<Case>();
        for (Case request : maintenanceRequests) {
            Case oldRequest = oldMap.get(request.Id);
            if (oldRequest != null && oldRequest.Status != 'Closed' && request.Status == 'Closed' && 
                (request.Type == 'Repair' || request.Type == 'Routine Maintenance')) {
                closedRequests.add(request);
            }
        }

        //debug statement to see closed requests
        System.debug('In Helper Class: Closed Requests: ' + closedRequests);

        //Step 2 - get the Maintenance Equipment and Equipment records related to the closed requests
        //A request can have multiple maintenance equipment records, and an equipment can be associate with multiple maintenance equipment records. 
        List<Id> requestIds = new List<Id>();
        for (Case request : closedRequests) {
            requestIds.add(request.Id);
        }
        List<Equipment_Maintenance_Item__c> maintenanceEquipments = [SELECT Id, Maintenance_Request__c, Equipment__c FROM Equipment_Maintenance_Item__c WHERE Maintenance_Request__c IN :requestIds];
        Set<Id> equipmentIds = new Set<Id>();
        for (Equipment_Maintenance_Item__c me : maintenanceEquipments) {
            equipmentIds.add(me.Equipment__c);
        }
        List<Product2> equipments = [SELECT Id, Maintenance_Cycle__c FROM Product2 WHERE Id IN :equipmentIds];

        //debug statements to see related maintenance equipment and equipment records
        System.debug('In Helper Class: Related Maintenance Equipments: ' + maintenanceEquipments);
        System.debug('In Helper Class: Related Equipments: ' + equipments);

        //Step 3 - for each closed maintenance request, calculate the shortest maintenance cycle from its related equipment records
        //Store the shortest maintenance cycle in a map with the case ID as the key and the shortest maintenance cycle as the value
        Map<Id, Decimal> equipmentMaintenanceCycles = new Map<Id, Integer>();
        for (Case request : closedRequests) {
            Decimal shortestCycle = null;
            for (Equipment_Maintenance_Item__c me : maintenanceEquipments) {
                if (me.Maintenance_Request__c == request.Id) {
                    for (Product2 eq : equipments) {
                        if (eq.Id == me.equipment__c) {
                            if (shortestCycle == null || eq.Maintenance_Cycle__c < shortestCycle) {
                                shortestCycle = eq.Maintenance_Cycle__c;
                            }
                        }
                    }
                }
            }
            if (shortestCycle != null) {
                equipmentMaintenanceCycles.put(request.Id, shortestCycle.intValue());
            }
        }
        //debug statement to see shortest maintenance cycles
        System.debug('In Helper Class: Equipment Maintenance Cycles: ' + equipmentMaintenanceCycles);

        // Step 4 - create new maintenance request for future routine checkup
        // The new request is tied to the same Vehicle and Equipment records as the original closed request
        // The maintenance cycle for the new request is set to the shortest maintenance cycle from the parent closed request
        List<Case> newRequests = new List<Case>();
        for (Case closedRequest : closedRequests) {
            Case newRequest = closedRequest.clone(); // Clone the closed request to create a new one
            newRequest.ParentId = closedRequest.Id; // Set the ParentId to the closed request's Id
            newRequest.Status = 'New'; // Set the status to New for the new request
            newRequest.Vehicle__c = closedRequest.Vehicle__c; // Assuming Vehicle__c is the field for Vehicle
            newRequest.ProductId = closedRequest.ProductId; // Assuming ProductId is the field for Equipment
            newRequest.Type = 'Routine Maintenance';
            newRequest.Subject = 'Routine Checkup'; // Set a meaningful subject
            //// Set the due date based on the shortest maintenance cycle
            Decimal maintenanceCycle = equipmentMaintenanceCycles.get(closedRequest.Id);
            if (maintenanceCycle != 0) {
                newRequest.Date_Due__c = System.today().addDays(maintenanceCycle.intValue()); // Assuming Due_Date__c is the field for due date
            } else {
                newRequest.Date_Due__c = System.today().addDays(30); // Default to 30 days if no maintenance cycle found
            }
            newRequest.Date_Reported__c = System.today(); // Assuming Date_Reported__c is the field for reported date
            newRequests.add(newRequest);
    }
        //debug statement to see new maintenance requests
        System.debug('In Helper Class: New Maintenance Requests: ' + newRequests);
        //debug statement to compare the Equipment for the new and closed requests
        for (Case c:newRequests){
            System.debug('In Helper Class: New Request Case ID: ' + c.Id);
            System.debug('In Helper Class: New Request Equipment: ' + c.ProductId);
            System.debug('In Helper Class: New Request Parent ID: ' + c.ParentId);
            System.debug('In Helper Class: Closed Request Case ID: ' + oldMap.get(c.ParentId).Id);
            System.debug('In Helper Class: Closed Request Equipment: ' + oldMap.get(c.ParentId).ProductId);
        }

        //debug statement to see new maintenance requests count
        System.debug('In Helper Class: New Maintenance Requests Count: ' + newRequests.size());

        // Insert the new maintenance requests
        if (!newRequests.isEmpty()) {
            insert newRequests;
        }
        System.debug('In Helper Class: After Insert Of New Maintenance Requests');
        for (Case c:newRequests){
            System.debug('In Helper Class: New Request Case ID: ' + c.Id);
            System.debug('In Helper Class: New Request Equipment: ' + c.ProductId);
            System.debug('In Helper Class: New Request Parent ID: ' + c.ParentId);
            System.debug('In Helper Class: Closed Request Case ID: ' + oldMap.get(c.ParentId).Id);
            System.debug('In Helper Class: Closed Request Equipment: ' + oldMap.get(c.ParentId).ProductId);
        }

        // Step 5 - create new equipment maintenance items for the new maintenance requests
        List<Equipment_Maintenance_Item__c> newMaintenanceItems = new List<Equipment_Maintenance_Item__c>();
        for (Case newRequest : newRequests) {
            for (Equipment_Maintenance_Item__c me : maintenanceEquipments) {
                if (me.Maintenance_Request__c == newRequest.ParentId) {
                    Equipment_Maintenance_Item__c newMe = me.clone();
                    newMe.Maintenance_Request__c = newRequest.Id;
                    newMaintenanceItems.add(newMe);
                    }
            }
        }
        //debug statement to see new maintenance equipment items
        System.debug('In Helper Class: New Maintenance Equipment Items: ' + newMaintenanceItems);
        // Insert the new equipment maintenance items
        if (!newMaintenanceItems.isEmpty()) {
            insert newMaintenanceItems;
        }
    }
}