public with sharing class OpportunityListController {

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpportunities() {
        return [
            SELECT Id, Name, StageName
            FROM Opportunity
            WITH USER_MODE
            ORDER BY Name
            LIMIT 1000
        ];
    }

    @AuraEnabled
    public static void updateOpportunities(List<Opportunity> opportunities) {
        if (opportunities == null || opportunities.isEmpty()) {
            return;
        }
        try {
            update as user opportunities;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
