public class DisplayAccountandContact {
	@AuraEnabled
    public static list<Account> nameOfAccount(){
        return [Select Id, Name from Account limit 10];
    }
}