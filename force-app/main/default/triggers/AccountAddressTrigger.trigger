trigger AccountAddressTrigger on Account (before insert, before update) {
    List<Account> accs = new List<Account>();

    for(Account acc: Trigger.new) {
        if (acc.Match_Billing_Address__c == true) {
            acc.ShippingPostalCode = acc.BillingPostalCode;
            accs.add(acc);
        }
    }
}