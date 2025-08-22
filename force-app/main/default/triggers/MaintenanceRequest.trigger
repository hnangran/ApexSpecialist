trigger MaintenanceRequest on Case (before update, after update) {
    // ToDo: Call MaintenanceRequestHelper.updateWorkOrders
    List<Case> updatedMRequests = Trigger.new;
    Case newMRequest = new Case();
    List<Case> newMRequests = new List<Case>();
    
    for(Case request:updatedMRequests){
        newMRequest = request;

    }
}