public with sharing class AccountListController {

    @AuraEnabled(cacheable=true)
    public static List<Account> getAccounts() {
        return [
            SELECT Id, Name, Type, Industry, Phone, Rating, AnnualRevenue
            FROM Account
            WITH USER_MODE
            ORDER BY Name
            LIMIT 200
        ];
    }
}
