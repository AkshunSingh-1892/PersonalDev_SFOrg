@IsTest
public class MyIterableTest{
    
    @IsTest
    static void testIterableForLoop() {
        
        // Create list of strings
        List<String> strings = new List<String>{ 'Hello', 'World' };
        
        // Create instance of MyIterableCopy
        MyIterable myIterable = new MyIterable(strings);
        
        // Iterate using for-loop
        for (String s : myIterable) {
            System.debug(s);
        }
    }
}