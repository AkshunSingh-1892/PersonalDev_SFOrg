@RestResource(urlMapping='/apexSecurityRest')
global with sharing class ApexSecurityRest {
    @HttpGet
    global static Contact doGet() {
        Id recordId = RestContext.request.params.get('id');
        Contact result;
        if (recordId == null) {
           throw new FunctionalException('Id parameter is required');
        }

            SObjectAccessDecision results = 
            Security.stripInaccessible(AccessType.READABLE,
                 [SELECT id, Name, Title, Top_Secret__c, Account.Name, Description FROM Contact WHERE Id = :recordId]
                 );
          if(results.getRemovedFields().get('Contact').contains('Top_Secret__c')){
                for (sObject c : results.getRecords()) {
                  Contact con = (Contact)c;
                  con.Description = con.Account?.Name;
                }
            }

           return result;
      }
      public class FunctionalException extends Exception{}
      public class SecurityException extends Exception{}
}