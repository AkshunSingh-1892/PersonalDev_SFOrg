@isTest
private class AccountClaudePopulatedBatchTest {

    @TestSetup
    static void setup() {
        List<Account> accs = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            accs.add(new Account(Name = 'Test Acc ' + i));
        }
        insert accs;
    }

    @isTest
    static void populatesAllAccounts() {
        Test.startTest();
        Database.executeBatch(new AccountClaudePopulatedBatch(), 200);
        Test.stopTest();

        Integer flagged = [SELECT count() FROM Account WHERE Claude_Populated__c = true];
        System.assertEquals(10, flagged, 'All seeded accounts should be flagged');
    }

    @isTest
    static void skipsAlreadyPopulatedAccounts() {
        List<Account> all = [SELECT Id FROM Account];
        for (Integer i = 0; i < 5; i++) {
            all[i].Claude_Populated__c = true;
        }
        update all;

        Test.startTest();
        Database.executeBatch(new AccountClaudePopulatedBatch(), 200);
        Test.stopTest();

        Integer flagged = [SELECT count() FROM Account WHERE Claude_Populated__c = true];
        System.assertEquals(10, flagged, 'All accounts end up flagged');
    }

    @isTest
    static void executeHandlesEmptyScope() {
        AccountClaudePopulatedBatch batch = new AccountClaudePopulatedBatch();
        batch.execute(null, new List<Account>());
        batch.finish(null);
        System.assertEquals(0, batch.successCount, 'No successes on empty scope');
        System.assertEquals(0, batch.failureCount, 'No failures on empty scope');
        System.assert(batch.failureMessages.isEmpty(), 'No failure messages on empty scope');
    }

    @isTest
    static void recordsFailuresOnDmlError() {
        Account ghost = new Account(Name = 'Ghost');
        insert ghost;
        Id ghostId = ghost.Id;
        delete ghost;
        Database.emptyRecycleBin(new Id[]{ ghostId });

        AccountClaudePopulatedBatch batch = new AccountClaudePopulatedBatch();
        batch.execute(null, new List<Account>{ new Account(Id = ghostId) });
        batch.finish(null);

        System.assertEquals(0, batch.successCount, 'Hard-deleted record cannot succeed');
        System.assertEquals(1, batch.failureCount, 'Failure should be recorded');
        System.assertEquals(1, batch.failureMessages.size(), 'Failure message should be captured');
        System.assert(
            batch.failureMessages[0].contains(String.valueOf(ghostId)),
            'Message should reference the failing record Id'
        );
    }
}
