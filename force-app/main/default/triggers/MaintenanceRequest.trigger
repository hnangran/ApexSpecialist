/*
    Trigger Name: MaintenanceRequest
    Description: This trigger handles after update events on Case records to manage maintenance requests.
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

trigger MaintenanceRequest on Case (after update) {

    if(Trigger.isAfter && Trigger.isUpdate) {
        MaintenanceRequestHelper.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }   
    
}