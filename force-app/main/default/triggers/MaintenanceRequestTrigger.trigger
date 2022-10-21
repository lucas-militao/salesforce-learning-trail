trigger MaintenanceRequestTrigger on Case (after update) {
    Map<Id, Case> mapOfNewMaintenanceRequests = Trigger.newMap;
    Map<Id, Case> mapOfOldMaintenanceRequests = Trigger.oldMap;

    Map<Id, Case> mapOfClosedMaintenanceRequests = new Map<Id, Case>();
    List<id> listOfClosedMaintenanceRequestsIds = new List<id>();
    for (Id requestId : mapOfNewMaintenanceRequests.keySet()) {
        Case oldRequest = mapOfOldMaintenanceRequests.get(requestId);
        Case newRequest = mapOfNewMaintenanceRequests.get(requestId);

        if (oldRequest.status != 'closed' && newRequest.status == 'closed') {
            mapOfClosedMaintenanceRequests.put(requestId, newRequest);
            listOfClosedMaintenanceRequestsIds.add(requestId);
        }
    }

    if (listOfClosedMaintenanceRequestsIds.size() > 0) {
        Map<Id, List<Product2>> mapOfRequestsRelatedProducts = buildRequestsRelatedProductsMap(listOfClosedMaintenanceRequestsIds);

        if (mapOfRequestsRelatedProducts.size() > 0) {
            createMaintenanceRequest(mapOfClosedMaintenanceRequests, mapOfRequestsRelatedProducts);                  
        }   
    }
    
    //CREATE NEW MAINTENANCE REQUEST
    static private void createMaintenanceRequest(Map<Id,Case> closedRequests, Map<Id,List<Product2>> relatedProducts) {
        System.debug('relatedProducts: ' + relatedProducts);

        Map<Id, Case> mapOfRelatedNewCases = new Map<Id, Case>();

        for (Id requestId : closedRequests.keySet()) {
            System.debug('requestId: ' + requestId);
            Case closedRequest = closedRequests.get(requestId);
            Date dueDate = getRequestDueDate(relatedProducts.get(requestId));
            mapOfRelatedNewCases.put(requestId, new Case(
                Type = 'Routine Maintenance',
                Vehicle__c = closedRequest.Vehicle__c,
                Subject = closedRequest.Subject == null ? 'Routine Maintenance' : closedRequest.Subject,
                Date_Due__c = dueDate
            ));
        }

        insert mapOfRelatedNewCases.values();

        Map<Id,List<Product2>> newRequestsRelatedProducts = new Map<Id, List<Product2>>();
        for (Id requestId : closedRequests.keySet()) {
            newRequestsRelatedProducts.put(requestId, relatedProducts.get(requestId));
        }

        createEquipmentMaintenanceItems(mapOfRelatedNewCases, newRequestsRelatedProducts);
    }

    static private Date getRequestDueDate(List<Product2> relatedProducts) {
        Integer days = 0;
        for (Product2 p : relatedProducts) {
            Integer maintenanceCycle = Integer.valueOf(p.Maintenance_Cycle__c);
            if (days == 0) {
                days = maintenanceCycle;
            }
            if (days > maintenanceCycle) {
                days = maintenanceCycle;
            }
        }
        Date dueDate = System.today().addDays(days);

        return dueDate;
    }

    static private void createEquipmentMaintenanceItems(Map<id, Case> relatedNewRequests, Map<Id,List<Product2>> relatedProducts) {
        List<Equipment_Maintenance_Item__c> newEquipMainItems = new List<Equipment_Maintenance_Item__c>();
        for (Id requestId : relatedNewRequests.keySet()) {
            Id newRequestId = relatedNewRequests.get(requestId).Id;
            for (Product2 p : relatedProducts.get(requestId)) {
                newEquipMainItems.add(new Equipment_Maintenance_Item__c(
                    Equipment__c = p.Id,
                    Maintenance_Request__c = newRequestId
                ));
            }
        }
        System.debug('newEquipMainItems: ' + newEquipMainItems);
        insert newEquipMainItems;
    }

    static private Map<Id, List<Product2>> buildRequestsRelatedProductsMap(List<Id> maintenanceRequestsIds) {
        System.debug('maintenanceRequestsIds: ' + maintenanceRequestsIds);
        Map<Id, List<Product2>> requestsRelatedProducts = new Map<Id, List<Product2>>();
        
        Map<Id, Product2> mapOfEquipments = new Map<Id, Product2>();
        List<Id> equipmentsIds = new List<Id>();
        List<Equipment_Maintenance_Item__c> listOfEquipmentMaintenanceItems = [SELECT Id, Equipment__c, Maintenance_Request__c FROM Equipment_Maintenance_Item__c WHERE Maintenance_Request__c IN :maintenanceRequestsIds];
        
        System.debug('listOfEquipmentMaintenanceItems: ' + listOfEquipmentMaintenanceItems);
        
        for (Equipment_Maintenance_Item__c item : listOfEquipmentMaintenanceItems) {
            equipmentsIds.add(item.Equipment__c);
        }

        Map<Id, Product2> relatedProducts = new Map<Id, Product2>([SELECT Id, Maintenance_Cycle__c FROM Product2 WHERE Id IN : equipmentsIds]);

        System.debug('relatedProducts: ' + relatedProducts);
        
        for (Equipment_Maintenance_Item__c item : listOfEquipmentMaintenanceItems) {
            for ( Id equipmentId : relatedProducts.keySet() ) {
                if (item.Equipment__c == equipmentId) {
                    if (requestsRelatedProducts.get(item.Maintenance_Request__c) == null) {
                        requestsRelatedProducts.put(item.Maintenance_Request__c, new List<Product2>{relatedProducts.get(equipmentId)});
                    } else {
                        requestsRelatedProducts.get(item.Maintenance_Request__c).add(relatedProducts.get(equipmentId));
                    }
                }
            }
        }

        return requestsRelatedProducts;
    }
}