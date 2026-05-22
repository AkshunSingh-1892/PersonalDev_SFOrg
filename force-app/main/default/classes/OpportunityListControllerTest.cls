@isTest
private class OpportunityListControllerTest {

    @testSetup
    static void seedData() {
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 3; i++) {
            opps.add(new Opportunity(
                Name = 'Test Opp ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            ));
        }
        insert opps;
    }

    @isTest
    static void getOpportunitiesReturnsAllOrderedByName() {
        Test.startTest();
        List<Opportunity> result = OpportunityListController.getOpportunities();
        Test.stopTest();

        System.assertEquals(3, result.size(), 'Should return seeded opportunities');
        System.assertEquals('Test Opp 0', result[0].Name, 'Results should be ordered by Name');
        System.assertEquals('Prospecting', result[0].StageName, 'StageName should be populated');
    }

    @isTest
    static void updateOpportunitiesPersistsStageChanges() {
        List<Opportunity> opps = [SELECT Id, StageName FROM Opportunity];
        for (Opportunity o : opps) {
            o.StageName = 'Qualification';
        }

        Test.startTest();
        OpportunityListController.updateOpportunities(opps);
        Test.stopTest();

        for (Opportunity o : [SELECT StageName FROM Opportunity]) {
            System.assertEquals('Qualification', o.StageName, 'Stage should be updated');
        }
    }

    @isTest
    static void updateOpportunitiesHandlesNullAndEmptySafely() {
        Test.startTest();
        OpportunityListController.updateOpportunities(null);
        OpportunityListController.updateOpportunities(new List<Opportunity>());
        Test.stopTest();
    }

    @isTest
    static void updateOpportunitiesThrowsOnInvalidStage() {
        List<Opportunity> opps = [SELECT Id FROM Opportunity LIMIT 1];
        opps[0].StageName = 'NotARealStage';

        Boolean threw = false;
        Test.startTest();
        try {
            OpportunityListController.updateOpportunities(opps);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Expected AuraHandledException for invalid stage value');
    }
}
