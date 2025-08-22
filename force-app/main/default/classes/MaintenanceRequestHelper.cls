/*
    Contains the application logic for the MaintenanceRequest trigger.
    The logic must meet the following requirements:
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
    11. For now, don’t worry about changes that occur on the equipment record itself.
    12. Also expose the logic for other uses in the org. 
    13.Separate the trigger (named MaintenanceRequest) from the application logic in the handler (named MaintenanceRequestHelper).

    
*/

/*
public with sharing class MaintenanceRequestHelper {
    public MaintenanceRequestHelper() {

    }

    public static void handleAfterUpdate(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        List<Case> casesToInsert = new List<Case>();
        Set<Id> caseIds = new Set<Id>();
        Set<Id> equipmentIds = new Set<Id>();

        for (Case newCase : newCases) {
            Case oldCase = oldCaseMap.get(newCase.Id);
            if (isEligibleForNewRequest(newCase, oldCase)) {
                caseIds.add(newCase.Id);
                //equipmentIds.addAll(getRelatedEquipmentIds(newCase.Id));
            }
        }

        if(!caseIds.isEmpty()) {
            equipmentIds.addAll(getRelatedEquipmentIds(caseIds));
        }

        if (!equipmentIds.isEmpty()) {
            Map<Id, Equipment__c> equipmentMap = new Map<Id, Equipment__c>([
                SELECT Id, Maintenance_Cycle__c 
                FROM Equipment__c 
                WHERE Id IN :equipmentIds
            ]);

            for (Case newCase : newCases) {
                Case oldCase = oldCaseMap.get(newCase.Id);
                if (isEligibleForNewRequest(newCase, oldCase)) {
                    Date dueDate = calculateDueDate(equipmentMap, getRelatedEquipmentIds(newCase.Id));
                    if (dueDate != null) {
                        Case newRequest = createNewMaintenanceRequest(newCase, dueDate);
                        casesToInsert.add(newRequest);
                    }
                }
            }
        }

        if (!casesToInsert.isEmpty()) {
            insert casesToInsert;
        }
    }



    private static Boolean isEligibleForNewRequest(Case newCase, Case oldCase) {
        return oldCase.Status != 'Closed' && newCase.Status == 'Closed' &&
               (newCase.Type == 'Repair' || newCase.Type == 'Routine Maintenance');
    }
    private static Set<Id> getRelatedEquipmentIds(Id caseId) {
        Set<Id> equipmentIds = new Set<Id>();
        for (Case_Equipment__c ce : [
            SELECT Equipment__c 
            FROM Case_Equipment__c 
            WHERE Case__c = :caseId
        ]) {
            equipmentIds.add(ce.Equipment__c);
        }
        return equipmentIds;
    }
    private static Date calculateDueDate(Map<Id, Equipment__c> equipmentMap, Set<Id> equipmentIds) {
        Integer minCycle = null;
        for (Id eqId : equipmentIds) {
            Equipment__c eq = equipmentMap.get(eqId);
            if (eq != null && eq.Maintenance_Cycle__c != null) {
                if (minCycle == null || eq.Maintenance_Cycle__c < minCycle) {
                    minCycle = eq.Maintenance_Cycle__c;     
                }
            }
        }
        return minCycle != null ? Date.today().addDays(minCycle) : null;
    }
    private static Case createNewMaintenanceRequest(Case originalCase, Date dueDate) {
        Case newCase = new Case();
        newCase.Subject = originalCase.Subject != null ? originalCase.Subject : 'Routine Maintenance Checkup';
        newCase.Type = 'Routine Maintenance';
        newCase.Report_Date__c = Date.today();
        newCase.Due_Date__c = dueDate;
        newCase.Vehicle__c = originalCase.Vehicle__c;
        newCase.Equipment__c = originalCase.Equipment__c;
        return newCase;
    }
}
*/


public with sharing class MaintenanceRequestHelper {
    public MaintenanceRequestHelper() {

    }

    public static void handleAfterUpdate(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        //store caseIds to recreate maintenance requests
        Set<Id> caseIds = new Set<Id>();        

        //store a list of cases to insert
        List<Case> casesToInsert = new List<Case>();

        //debug statement to check the number of cases being processed
        System.debug('Number of cases being processed: ' + newCases.size());

        //See if the case is eligible to create a new maintenance request and collect the case ID
        for (Case newCase : newCases) {
            Case oldCase = oldCaseMap.get(newCase.Id);
            if (isEligibleForNewRequest(newCase, oldCase)) {
                caseIds.add(newCase.Id);
            }
        }

        //Debug statement to check the number of eligible cases
        System.debug('Number of eligible cases for new maintenance requests: ' + caseIds.size());


        //If there are no eligible cases, exit early
        if (caseIds.isEmpty()) {
            return;
        }

        //Get related equipment maintenance items
        List<Equipment_Maintenance_Item__c> equipmentMaintenanceItems = getRelatedEquipmentMaintenanceItems(caseIds);

        //Map equipment maintenance items to cases
        Map<Id, Equipment_Maintenance_Item__c> equipmentMaintenanceMap = createCaseToEquipmentMaintenanceMap(equipmentMaintenanceItems);

        //Get related equipment records
        List<Product2> relatedEquipments = getRelatedEquipmnents(equipmentMaintenanceItems);

        //Create a map of cases to maintenance cycles based on related equipments
        Map<Id, Integer> caseToMaintenanceCycleMap = getCaseToMaintenanceCycleMap(equipmentMaintenanceMap, relatedEquipments);        

        //Create new maintenance requests with calculated due dates
        for(Id caseID : caseIds) {
            Case originalCase = oldCaseMap.get(caseID);
            Integer maintenanceCycle = caseToMaintenanceCycleMap.get(caseID);
            if (maintenanceCycle != null) {
                Date dueDate = Date.today().addDays(maintenanceCycle);
                Case newRequest = createNewMaintenanceRequest(originalCase, dueDate);
                casesToInsert.add(newRequest);
            }
        }

        //Insert new maintenance requests if there are any
        if (!casesToInsert.isEmpty()) {
            try {
                insert casesToInsert;
            } catch (DmlException e) {
                System.debug('Error inserting new maintenance requests: ' + e.getMessage());
            }
        }

        //insert new equipment maintenance items for the new maintenance requests 
        List<Equipment_Maintenance_Item__c> newEquipmentMaintenanceItems = new List<Equipment_Maintenance_Item__c>();

        for (Case newCase : casesToInsert) {
            List<Equipment_Maintenance_Item__c> maintenanceItems = equipmentMaintenanceMap.get(newCase.parentId);
            if (maintenanceItems == null) {
                continue; // No related items to copy
            }
            // Create new equipment maintenance items for the new case

            List<Equipment_Maintenance_Item__c> clonedMaintenanceItems = new List<Equipment_Maintenance_Item__c>();
            clonedMaintenanceItems = maintenanceItems.clone();

            for (Equipment_Maintenance_Item__c item : clonedMaintenanceItems) {
                newItem.Maintenance_Request__c = newCase.Id;
                newEquipmentMaintenanceItems.add(newItem);
            }
        }

        // Insert the new equipment maintenance items
        if (!newEquipmentMaintenanceItems.isEmpty()) {
            try {
                insert newEquipmentMaintenanceItems;
            } catch (DmlException e) {
                System.debug('Error inserting new equipment maintenance items: ' + e.getMessage());
            }
        }
    }

    private static Boolean isEligibleForNewRequest(Case newCase, Case oldCase) {
        return oldCase.Status != 'Closed' && newCase.Status == 'Closed' &&
               (newCase.Type == 'Repair' || newCase.Type == 'Routine Maintenance');
    }

    private static List<Equipment_Maintenance_Item__c> getRelatedEquipmentMaintenanceItems(Set<Id> caseIds) {

        List<Equipment_Maintenance_Item__c> equipmentMaintenanceItems = new List<Equipment_Maintenance_Item__c>();

        equipmentMaintenanceItems = [SELECT Id, Equipment__c, Maintenance_Request__c 
                            FROM Equipment_Maintenance_Item__c 
                            WHERE Maintenance_Request__c IN :caseIds
        ];

        return equipmentMaintenanceItems;
    }    

    private static Map<Id, List<Equipment_Maintenance_Item__c>> createCaseToEquipmentMaintenanceMap(List<Equipment_Maintenance_Item__c> equipmentMaintenanceItems) {

        Map<Id, List<Equipment_Maintenance_Item__c>> equipmentMaintenanceMap = new Map<Id, List<Equipment_Maintenance_Item__c>>();

        for (Equipment_Maintenance_Item__c item : equipmentMaintenanceItems) {
            if (!equipmentMaintenanceMap.containsKey(item.Maintenance_Request__c)) {
                equipmentMaintenanceMap.put(item.Maintenance_Request__c, new List<Equipment_Maintenance_Item__c>());
            }
            equipmentMaintenanceMap.get(item.Maintenance_Request__c).add(item);
        }

        return equipmentMaintenanceMap;
    }

    private static List<Product2> getRelatedEquipmnents(List<Equipment_Maintenance_Item__c> equipmentMaintenanceItems) {
        Set<Id> equipmentIds = new Set<Id>();
        for (Equipment_Maintenance_Item__c item : equipmentMaintenanceItems) {
            if (item.Equipment__c != null) {
                equipmentIds.add(item.Equipment__c);
            }
        }

        return [SELECT Id, Maintenance_Cycle__c FROM Product2 WHERE Id IN :equipmentIds];
    }

    private static Map<Id, Integer> getCaseToMaintenanceCycleMap(Map<Id, List<Equipment_Maintenance_Item__c>> equipmentMaintenanceMap, List<Product2> relatedEquipments) {
        Map<Id, Integer> caseToMaintenanceCycleMap = new Map<Id, Integer>();

        for (Product2 equipment : relatedEquipments) {
            if (equipment.Maintenance_Cycle__c != null) {
                for (Equipment_Maintenance_Item__c item : equipmentMaintenanceMap.get(equipment.Id)) {
                    if (!caseToMaintenanceCycleMap.containsKey(item.Maintenance_Request__c) || 
                        equipment.Maintenance_Cycle__c < caseToMaintenanceCycleMap.get(item.Maintenance_Request__c)) {
                        caseToMaintenanceCycleMap.put(item.Maintenance_Request__c, equipment.Maintenance_Cycle__c);
                    }
                }
            }
        }

        return caseToMaintenanceCycleMap;
    }

    private static Date calculateDueDate(Map<Id, Equipment__c> equipmentMap, Set<Id> equipmentIds) {
        Integer minCycle = null;
        for (Id eqId : equipmentIds) {
            Equipment__c eq = equipmentMap.get(eqId);
            if (eq != null && eq.Maintenance_Cycle__c != null) {
                if (minCycle == null || eq.Maintenance_Cycle__c < minCycle) {
                    minCycle = eq.Maintenance_Cycle__c;     
                }
            }
        }
        return minCycle != null ? Date.today().addDays(minCycle) : null;
    }

    private static Case createNewMaintenanceRequest(Case originalCase, Date dueDate) {
        Case newCase = new Case();
        newCase.Subject = originalCase.Subject != null ? originalCase.Subject : 'Routine Maintenance Checkup';
        newCase.Type = 'Routine Maintenance';
        newCase.Report_Date__c = Date.today();
        newCase.Due_Date__c = dueDate;
        newCase.Vehicle__c = originalCase.Vehicle__c;
        newCase.Equipment__c = originalCase.Equipment__c;
        newCase.parentId = originalCase.Id; // Link to the original case
        newCase.Status = 'New'; // Set the status for the new request
        return newCase;
    }
}
