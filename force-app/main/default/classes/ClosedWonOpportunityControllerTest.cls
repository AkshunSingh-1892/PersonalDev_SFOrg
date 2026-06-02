@isTest
private class ClosedWonOpportunityControllerTest {
  @testSetup
  static void seedData() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    List<Opportunity> opps = new List<Opportunity>{
      new Opportunity(
        Name = 'Closed Won A',
        AccountId = acc.Id,
        StageName = 'Closed Won',
        Amount = 10000,
        CloseDate = Date.today().addDays(-10)
      ),
      new Opportunity(
        Name = 'Closed Won B',
        AccountId = acc.Id,
        StageName = 'Closed Won',
        Amount = 20000,
        CloseDate = Date.today().addDays(-5)
      ),
      new Opportunity(
        Name = 'Closed Won C',
        AccountId = acc.Id,
        StageName = 'Closed Won',
        Amount = 5000,
        CloseDate = Date.today().addDays(-1)
      ),
      new Opportunity(
        Name = 'Prospecting Opp',
        AccountId = acc.Id,
        StageName = 'Prospecting',
        Amount = 8000,
        CloseDate = Date.today().addDays(30)
      )
    };
    insert opps;
  }

  @isTest
  static void getClosedWonOpportunitiesReturnsOnlyClosedWon() {
    Test.startTest();
    List<Opportunity> result = ClosedWonOpportunityController.getClosedWonOpportunities();
    Test.stopTest();

    System.assertEquals(
      3,
      result.size(),
      'Should return only Closed Won opportunities'
    );
    for (Opportunity opp : result) {
      System.assertEquals(
        'Closed Won',
        opp.StageName,
        'All results must be Closed Won'
      );
    }
  }

  @isTest
  static void getClosedWonOpportunitiesReturnsCorrectFields() {
    Test.startTest();
    List<Opportunity> result = ClosedWonOpportunityController.getClosedWonOpportunities();
    Test.stopTest();

    System.assertNotEquals(0, result.size(), 'Expected at least one result');
    Opportunity first = result[0];
    System.assertNotEquals(null, first.Name, 'Name should be populated');
    System.assertNotEquals(null, first.Amount, 'Amount should be populated');
    System.assertNotEquals(
      null,
      first.StageName,
      'StageName should be populated'
    );
    System.assertNotEquals(
      null,
      first.Account,
      'Account relationship should be populated'
    );
    System.assertNotEquals(
      null,
      first.Account.Name,
      'Account.Name should be populated'
    );
    System.assertNotEquals(
      null,
      first.Owner,
      'Owner relationship should be populated'
    );
    System.assertNotEquals(
      null,
      first.Owner.Name,
      'Owner.Name should be populated'
    );
  }

  @isTest
  static void getClosedWonOpportunitiesReturnsEmptyForNone() {
    delete [SELECT Id FROM Opportunity WHERE StageName = 'Closed Won'];

    Test.startTest();
    List<Opportunity> result = ClosedWonOpportunityController.getClosedWonOpportunities();
    Test.stopTest();

    System.assert(
      result.isEmpty(),
      'Should return empty list when no Closed Won records exist'
    );
  }

  @isTest
  static void getClosedWonOpportunitiesOrderedByName() {
    Test.startTest();
    List<Opportunity> result = ClosedWonOpportunityController.getClosedWonOpportunities();
    Test.stopTest();

    System.assertEquals(3, result.size(), 'Expected 3 Closed Won records');
    System.assertEquals(
      'Closed Won A',
      result[0].Name,
      'First record should be Closed Won A'
    );
    System.assertEquals(
      'Closed Won B',
      result[1].Name,
      'Second record should be Closed Won B'
    );
    System.assertEquals(
      'Closed Won C',
      result[2].Name,
      'Third record should be Closed Won C'
    );
  }
}
