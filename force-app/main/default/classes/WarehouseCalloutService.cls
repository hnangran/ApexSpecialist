/**
 * Service class to handle callouts to the Warehouse Management System (WMS).
 * Implements Queueable to allow asynchronous processing of callouts.
 * 1. This class makes a REST callout to an external warehouse system to get a list of equipment that needs to be updated. 
 * 2. The callout’s JSON response returns the equipment records that will be upserted in Salesforce. 
 * 3. Beyond inventory, ensure that other potential warehouse changes carry over to Salesforce. 
 * 4. This class maps the following fields:
 *   a. Replacement part (this should be set to true for all records that come in from the warehouse system)
 *   b. Cost
 *   c. Current inventory
 *   d. Lifespan
 *   e. Maintenance cycle
 *   f. Warehouse SKU
 * 5. Use the warehouse SKU as the external ID to identify which equipment records to update within Salesforce.
 * 6. Although HowWeRoll is an international company, the remote offices follow the lead of the HQ’s work schedule. 
 * 7. Therefore, all maintenance requests are processed during HQ’s normal business hours. 
 * 8. You need to update Salesforce data during off hours (at 1:00 AM). 
 * 9. This logic runs daily so that the inventory is up to date every morning at HQ.
 */

public with sharing class WarehouseCalloutService implements Queueable, Database.AllowsCallouts{
    public WarehouseCalloutService() {

    }

    public void execute(QueueableContext context) {

        //1. Prepare for the callout
        // Define the endpoint URL
        String endpoint = 'https://th-superbadge-apex.herokuapp.com/equipment'; 
        // Create a new HTTP request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(2000); // Set timeout to 2 seconds
        HttpResponse response = new Http().send(req);

        // If the request is successful, parse the JSON response.
        if(response.getStatusCode() != 200)
        {
            System.debug('Callout failed: ' + response.getStatusCode() + ' ' + response.getStatus());
            throw new CalloutException('Warehouse callout failed: ' + response.getStatusCode() + ' ' + response.getStatus());
        }

        //2. Parse the JSON response
        String jsonResponse = response.getBody();
        List<EquipmentPayload> equipmentList = (List<EquipmentPayload>) JSON.deserialize(jsonResponse, List<EquipmentPayload>.class);
        //debug statement to see parsed equipment list
        System.debug('In WarehouseCalloutService Class: Parsed Equipment List: ' + equipmentList);

        //3. convert list to map for easier processing
        Map<String, EquipmentPayload> equipmentPayloadMap = new Map<String, EquipmentPayload>();
        for(EquipmentPayload ep : equipmentList){
            equipmentPayloadMap.put(ep.sku, ep);
        }
        //debug statement to see EquipmentPayload map
        System.debug('In WarehouseCalloutService Class: EquipmentPayload Map: ' + equipmentPayloadMap);
        
        //4. Get existing equipments to prepare for upsert
        Map<String, Product2> existingProductsMap = new Map<String, Product2>(
                                                            [SELECT Id, Replacement_Part__c, Cost__c, Current_Inventory__c, 
                                                                   Lifespan_Months__c, Maintenance_Cycle__c, Warehouse_SKU__c 
                                                            FROM Product2 
                                                            WHERE Warehouse_SKU__c IN : equipmentPayloadMap.keySet()]
                                                        );

        //debug statement to see existing products map
        System.debug('In WarehouseCalloutService Class: Existing Products Map: ' + existingProductsMap);

        //5. Prepare equipment records for upsert
        List<Product2> productsToUpsert = new List<Product2>();
        for(EquipmentPayload ep : equipmentPayloadMap.values()){
            Product2 prod;
            if(existingProductsMap.containsKey(ep.sku)){
                prod = existingProductsMap.get(ep.sku);
            } else {
                prod = new Product2();
                prod.Warehouse_SKU__c = ep.sku; // set external ID for new records
            }
            prod.name = ep.name;
            prod.Replacement_Part__c = true; // set to true for all records from warehouse
            prod.Cost__c = ep.cost;
            prod.Current_Inventory__c = ep.quantity;
            prod.Lifespan_Months__c = ep.lifespan;
            prod.Maintenance_Cycle__c = ep.maintenanceperiod;
            productsToUpsert.add(prod);
        }

        //debug statement to see products to upsert
        System.debug('In WarehouseCalloutService Class: Products to Upsert: ' + productsToUpsert);

        
        //6. Upsert the equipment records
        if(!productsToUpsert.isEmpty()){
            upsert productsToUpsert;
        }
        System.debug('In WarehouseCalloutService Class: Upserted Products: ' + productsToUpsert);

    }

    class EquipmentPayload {
        String Id;
        boolean replacement;
        Integer quantity;
        String name;
        Integer maintenanceperiod;
        Integer lifespan;
        Decimal cost;
        String sku;
    }
}

