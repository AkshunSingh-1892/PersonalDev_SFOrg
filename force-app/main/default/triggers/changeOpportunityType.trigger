trigger changeOpportunityType on OpportunityLineItem (after insert, after update) {
Set<Id> SetOfOpportunity  = new Set<Id>();
Set<Id> setOfProduct2Id = new Set<Id>();
for(OpportunityLineItem OppLine : trigger.new){
system.debug('ProductId'+OppLine.Product2Id);
    setOfProduct2Id.add(OppLine.Product2Id);
}
List<Product2> listOfProduct2 = new List<Product2>();
set<Id> FinalProduct2Id = new set<Id>();
listOfProduct2 = [Select Id, Family from product2 where Id IN :setOfProduct2Id and Family = 'Sponsor'];
if(listOfProduct2.size() > 0){
    for(product2 Pro: listOfProduct2){
    system.debug('ProductId 2'+Pro.Id);
        FinalProduct2Id.add(Pro.Id);
    }
}
for(OpportunityLineItem OppLine : trigger.new){
    if(FinalProduct2Id.contains(OppLine.Product2Id)){
        system.debug('OpportunityId'+OppLine.OpportunityId);
        SetOfOpportunity.add(OppLine.OpportunityId);
    }
}   
    List<Opportunity> OppList  = new List<Opportunity>();
    List<Opportunity> finalListToUpdate = new List<Opportunity>();
    OppList = [Select Id, Type From Opportunity where Id IN :SetOfOpportunity];
    if(OppList.size() > 0){
    for(Opportunity Opp : OppList){
        Opp.Type = 'Sponsor';
        finalListToUpdate.add(Opp);
    
    }
    if(finalListToUpdate.size() > 0){
        update finalListToUpdate;
    }
}
}