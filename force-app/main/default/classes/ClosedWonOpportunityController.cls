public with sharing class ClosedWonOpportunityController {
  @AuraEnabled(cacheable=true)
  public static List<Opportunity> getClosedWonOpportunities() {
    return [
      SELECT Id, Name, Account.Name, Amount, Owner.Name, StageName
      FROM Opportunity
      WHERE StageName = 'Closed Won'
      WITH USER_MODE
      ORDER BY Name
      LIMIT 1000
    ];
  }
}
