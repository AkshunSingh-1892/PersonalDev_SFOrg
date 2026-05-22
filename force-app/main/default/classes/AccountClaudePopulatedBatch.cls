public with sharing class AccountClaudePopulatedBatch
    implements Database.Batchable<sObject>, Database.Stateful {

    @TestVisible private Integer successCount = 0;
    @TestVisible private Integer failureCount = 0;
    @TestVisible private List<String> failureMessages = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id, Claude_Populated__c FROM Account WHERE Claude_Populated__c = false'
        );
    }

    public void execute(Database.BatchableContext bc, List<Account> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        if (!Schema.sObjectType.Account.isUpdateable()
            || !Account.Claude_Populated__c.getDescribe().isUpdateable()) {
            failureCount += scope.size();
            failureMessages.add(
                'FLS/CRUD denied: Account.Claude_Populated__c not updateable for the running user.'
            );
            return;
        }

        List<Account> toUpdate = new List<Account>();
        for (Account a : scope) {
            toUpdate.add(new Account(Id = a.Id, Claude_Populated__c = true));
        }

        Database.SaveResult[] results = Database.update(toUpdate, false);
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult sr = results[i];
            if (sr.isSuccess()) {
                successCount++;
            } else {
                failureCount++;
                List<String> errs = new List<String>();
                for (Database.Error err : sr.getErrors()) {
                    errs.add(err.getStatusCode() + ': ' + err.getMessage());
                }
                failureMessages.add(toUpdate[i].Id + ' -> ' + String.join(errs, '; '));
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO,
            'AccountClaudePopulatedBatch finished. Success=' + successCount
            + ', Failures=' + failureCount);
        if (!failureMessages.isEmpty()) {
            System.debug(LoggingLevel.ERROR,
                'AccountClaudePopulatedBatch failure detail: '
                + String.join(failureMessages, ' | '));
        }
    }
}
