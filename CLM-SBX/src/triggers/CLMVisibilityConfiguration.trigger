trigger CLMVisibilityConfiguration on CLM_Visibility_Configuration__c (before insert, before update) {
	
	
	//NOTE::allValidEntities() also updates the Trigger.New for Entity Id and Entity Name values
	if(!CLMVisibilityManagerUtil.allValidEntities(Trigger.new)){
			Trigger.new[0].addError('One or more Configuration objects in the batch have invalid Entity Name');		
	}
	for(CLM_Visibility_Configuration__c aCVC: Trigger.new){
		aCVC.External_Id__c = aCVC.Entity_Id__c;
		if(aCVC.Use_Custom_Criteria__c){
			aCVC.Available_CLM_Presentations_1__c = '';
			aCVC.Available_CLM_Presentations_2__c = '';
		}
		else
		{
			aCVC.Custom_Criteria__c = '';
			aCVC.Exclusive_criteria__c = false;
			Set<String> clmPreziNames = new Set<String> ();
			if(aCVC.Available_CLM_Presentations_1__c!=null 
					&& aCVC.Available_CLM_Presentations_1__c.trim()!=';'
					&& aCVC.Available_CLM_Presentations_1__c.trim()!=''){
				clmPreziNames.addAll(aCVC.Available_CLM_Presentations_1__c.trim().split(';'));
			}
			if(aCVC.Available_CLM_Presentations_2__c!=null
					&& aCVC.Available_CLM_Presentations_2__c.trim()!=';'
					&& aCVC.Available_CLM_Presentations_2__c.trim()!=''){
				clmPreziNames.addAll(aCVC.Available_CLM_Presentations_2__c.trim().split(';'));
			}
				if(clmPreziNames.size() == 0){
					return;
				}
				Set<String> cleanClmPreziNames = new Set<String> ();
				for(String aName: clmPreziNames){
					if(aName!=null && aName.trim() != ''){
						cleanClmPreziNames.add(aName);
					}
				}
				AggregateResult[] agg = [Select count(Id) CNT from CLM_Presentation_vod__c where Name in: cleanClmPreziNames];
				
				Integer dbCount = (Integer) agg[0].get('CNT');
				
				
				if(dbCount!=cleanClmPreziNames.size()){
						Trigger.new[0].addError('One or more CLM Presentation Names is Invalid.');				
				}
		}		
	}		
}