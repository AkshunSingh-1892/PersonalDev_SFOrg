@isTest
private class AccountListControllerTest {

    @TestSetup
    static void setup() {
        List<Account> accs = new List<Account>();
        accs.add(new Account(
            Name = 'Alpha Corp',
            Type = 'Customer - Direct',
            Industry = 'Technology',
            Phone = '555-0001',
            Rating = 'Hot',
            AnnualRevenue = 5000000
        ));
        accs.add(new Account(
            Name = 'Beta LLC',
            Type = 'Customer - Channel',
            Industry = 'Finance',
            Phone = '555-0002',
            Rating = 'Warm',
            AnnualRevenue = 1500000
        ));
        accs.add(new Account(
            Name = 'Gamma Inc',
            Type = 'Prospect',
            Industry = 'Healthcare',
            Phone = '555-0003',
            Rating = 'Cold',
            AnnualRevenue = 250000
        ));
        insert accs;
    }

    @isTest
    static void returnsAccountsOrderedByName() {
        Test.startTest();
        List<Account> result = AccountListController.getAccounts();
        Test.stopTest();

        System.assertEquals(3, result.size(), 'All seeded accounts should be returned');
        System.assertEquals('Alpha Corp', result[0].Name, 'Results should be ordered by Name asc');
        System.assertEquals('Beta LLC', result[1].Name);
        System.assertEquals('Gamma Inc', result[2].Name);
    }

    @isTest
    static void returnsSelectedFields() {
        List<Account> result = AccountListController.getAccounts();
        Account first = result[0];

        System.assertEquals('Customer - Direct', first.Type);
        System.assertEquals('Technology', first.Industry);
        System.assertEquals('555-0001', first.Phone);
        System.assertEquals('Hot', first.Rating);
        System.assertEquals(5000000, first.AnnualRevenue);
    }
}
