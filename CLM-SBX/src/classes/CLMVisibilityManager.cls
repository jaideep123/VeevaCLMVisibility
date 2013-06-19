/**
* @author - Murugesh Naidu, Veeva Systems Inc
* @className - CLMVisibilityManager.cls
* @description - Controller class for CLM Visibility Manager
* @createdate - March 18th, 2012
*
*/

public class CLMVisibilityManager {

    public SelectOption[] selectedCLMPrezis { get; set; }
    public SelectOption[] selectedCLMPrezisBeforeChange { get; set; }
    public SelectOption[] originallyAvailablePrezis { get; set; }
    public SelectOption[] allCLMPresentations { get; set; }
    public Set<ID> unChangedPrezisSet { get; set; }
    public Set<ID> ALL_RELATED_TERRITORY_IDS ;
    public Set<ID> ALL_RELATED_ROLE_IDS ;
    public Set<ID> ALL_RELATED_PUBLIC_GROUP_IDS = new Set<ID> ();
    public String message { get; set; }
    public List<CLM_Presentation_vod__c> userAvailablePreziList;
    public List<CLM_Visibility_Manager_Transaction__c> transactionList;
    public Set<ID> newlyVisibleCLMIDs = new Set<ID>();
    public Set<ID> newlyInvisibleCLMIDs = new Set<ID>();
    public Boolean CLEAR_CACHE  { get; set; }
    public Boolean RENDER_PANEL  { get; set; }
    public Boolean HAS_ERROR  { get; set; }
    public Boolean IS_ADMIN  { get; set; }
    public Boolean HANDLE_KEY_MESSAGE_DOWNLOADS = true;
    public String DEFAULT_NO_CVC_BEHAVIOR = 'DISPLAY_ALL';
    public Set<String> VALID_DEFAULT_NO_CVC_BEHAVIOR_VALUES = new Set<String> {'DISPLAY_ALL', 'DISPLAY_NONE'};
    public String CLR_CACHE_STR  ;
    
    
    public String getCLR_CACHE_STR(){
    	return CLR_CACHE_STR;
    }
    public void setCLR_CACHE_STR(String x){
    	CLR_CACHE_STR = x;
    	CLEAR_CACHE = Boolean.valueOf(x);
    }
    
    /*
    * @methodDescription - Constructor - Populates the Available (Non-accessible) & Visible lists
    * of  <code>Clm_Presentation_vod__c</code>
    */

    public CLMVisibilityManager() {
    	CLEAR_CACHE = false;
    	HAS_ERROR = false;
		Profile loggedInProfile = [SELECT Id, Name, PermissionsModifyAllData, PermissionsViewAllData 
									FROM Profile 
									WHERE ID = :UserInfo.getProfileId()];   
		//retrieve the custom settings if there are any
		VPROF_CLM_Selector_Setting__c custSetting = VPROF_CLM_Selector_Setting__c.getInstance();
		if(custSetting!=null){ 
			if(custSetting.Default_No_CVC_Behavior__c!=null 
				&& VALID_DEFAULT_NO_CVC_BEHAVIOR_VALUES.contains(custSetting.Default_No_CVC_Behavior__c.trim())){
				DEFAULT_NO_CVC_BEHAVIOR = custSetting.Default_No_CVC_Behavior__c.trim();
			}
			if(custSetting.Enable_Key_Message_Download_Handling__c!=null){
				HANDLE_KEY_MESSAGE_DOWNLOADS = custSetting.Enable_Key_Message_Download_Handling__c;
			}
		}
		
		if(loggedInProfile!=null && 
				(loggedInProfile.PermissionsModifyAllData || loggedInProfile.PermissionsViewAllData )){
			IS_ADMIN = true;
			HAS_ERROR = true;
    		ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,CLMVisibilityManagerUtil.CLM_PREZI_EXCEPTION_ADMIN_NOT_ALLOWED)) ;
		}
		System.debug('UserInfo.getUserId() = ' + UserInfo.getUserId());
		System.debug('UserInfo.getUserRoleId() = ' + UserInfo.getUserRoleId());
        ALL_RELATED_TERRITORY_IDS = CLMVisibilityManagerUtil.getParentTerritoryIDs(UserInfo.getUserId());
        ALL_RELATED_ROLE_IDS = CLMVisibilityManagerUtil.getParentRoleIDs(UserInfo.getUserRoleId());
 			
        userAvailablePreziList = (List<CLM_Presentation_vod__c>) new UserSpecificOps().getUserVisiblePrezis(false);
        selectedCLMPrezis = CLMVisibilityManagerUtil.convertToSelectOptions(userAvailablePreziList);
        if(selectedCLMPrezis!=null){
	        originallyAvailablePrezis = new List<SelectOption> ();
	        originallyAvailablePrezis.addAll(selectedCLMPrezis);
	        selectedCLMPrezisBeforeChange = new List<SelectOption> ();
	        selectedCLMPrezisBeforeChange.addAll(selectedCLMPrezis);
        }
        allCLMPresentations =    getALLAvailableCLMPrezis(false);
        System.debug('selectedCLMPrezis = ' + selectedCLMPrezis);
        System.debug('originallyAvailablePrezis = ' + originallyAvailablePrezis);
        System.debug('allCLMPresentations = ' + allCLMPresentations);
        transactionList = new List<CLM_Visibility_Manager_Transaction__c>();
    }

	/*
	* @methodDescription: Updates visibility of  <code>Clm_Presentation_vod__c</code> objects for the user
	*/
    public PageReference updateVisibility() {
    	if(selectedCLMPrezisBeforeChange!=selectedCLMPrezis){
	    	System.Savepoint svp = Database.setSavepoint();
    		try{
	 	        updateCLMVisibility(selectedCLMPrezis);
	 	        if(HANDLE_KEY_MESSAGE_DOWNLOADS){
	 	        	handleKeyMessageDownloads();
	 	        }
//	 	        markCLMKeyMessagesForDownload();
	 	        recordTransactions();
	 	        doSystemResets();
		        message = CLMVisibilityManagerUtil.CLM_PREZI_SUCCESS_MSG;
    		}catch (Exception e){
    			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO,CLMVisibilityManagerUtil.CLM_PREZI_EXCEPTION_INTRO_MSG)) ;
    			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,e.getStackTraceString(), e.getStackTraceString())) ;
				Database.rollback(svp);
				HAS_ERROR = true;
    		}
    	}
    	else{
	        message = CLMVisibilityManagerUtil.CLM_PREZI_NOCHANGE_MSG;
    	}
        return null;       
    }
    
    //@deprecate
    private void handleKeyMessageDownloads_bakup_obsolete(){
    	//get whats visible to Available to User just on Product basis
    	List<CLM_Presentation_vod__c> defaultAvailable = [SELECT Name, Id FROM Clm_Presentation_vod__c
    													where Product_vod__c in: CLMVisibilityManagerUtil.getUserMySetupProductIDs(UserInfo.getUserId())] ;
    	System.debug('defaultAvailable = ' + defaultAvailable);
    	//compare this to list of CLM Presentations he actually has access to
    	List<SelectOption> userAvailable =  (List<SelectOption>) new UserSpecificOps().getUserVisiblePrezis(true);
     	System.debug('userAvailable = ' + userAvailable);
    	
    	Set<ID> defaultIDs = new Set<ID> ();
    	Set<ID> visibleIDs = new Set<ID> ();
    	
    	for(Clm_Presentation_vod__c aPrezi: defaultAvailable){
    		defaultIDs.add(aPrezi.Id);
    	}
     	System.debug('defaultIDs before = ' + userAvailable);
    	for(SelectOption anOption: userAvailable){
    		visibleIDs.add(anOption.getValue());
    	}
    	if(defaultIDs!=null && visibleIDs!=null){
    		defaultIDs.removeAll(visibleIDs);
    	}
     	System.debug('defaultIDs after = ' + userAvailable);
     	List<CLM_Presentation_vod__c> prezisToNOTDownload = [SELECT Id, 
    															(SELECT Id,Key_Message_vod__c FROM Clm_Presentation_Slide_vod__r), 
    															(SELECT Id,Key_Message_vod__c FROM Clm_Presentation_Slide_2_vod__r) 
    														FROM Clm_Presentation_vod__c
    														where Id in: defaultIDs];
    	
     	System.debug('prezisToNOTDownload  = ' + prezisToNOTDownload);
    	//Add a reference to Key Messages that are associated to Non-visible CLM Presentations into Invisible_CLM_Key_Message__c
    	Set<Invisible_CLM_Key_Message__c> invisibleKMObjSet = new Set<Invisible_CLM_Key_Message__c> ();
    	for(CLM_Presentation_vod__c aPrezi: prezisToNOTDownload){
    		for (Clm_Presentation_Slide_vod__c aSlide: aPrezi.Clm_Presentation_Slide_vod__r){
    			invisibleKMObjSet.add(new Invisible_CLM_Key_Message__c (
    								OwnerId = UserInfo.getUserId(), 
    								Key_Message__c = aSlide.Key_Message_vod__c, 
    								External_Id__c = UserInfo.getUserId() + '__' +aSlide.Key_Message_vod__c ));
    		}
    		for (Clm_Presentation_Slide_vod__c aSlide: aPrezi.Clm_Presentation_Slide_2_vod__r){
    			invisibleKMObjSet.add(new Invisible_CLM_Key_Message__c (
    								OwnerId = UserInfo.getUserId(), 
    								Key_Message__c = aSlide.Key_Message_vod__c, 
    								External_Id__c = UserInfo.getUserId() + '__' +aSlide.Key_Message_vod__c ));
    		}
    	}
    	//first clean out all Invisible KMs owned by this user
    	List<Invisible_CLM_Key_Message__c> invKMObjsToDelete = [select Id from Invisible_CLM_Key_Message__c where OwnerId = :UserInfo.getUserId()];
    	
    	if(invKMObjsToDelete!=null && invKMObjsToDelete.size() > 0){
    		delete invKMObjsToDelete;
    	}
    	System.debug('After delete: invKMObjsToDelete  = ' + invKMObjsToDelete);
    	
	   	//Now Insert to this table - a VMOC will typically use a NOT IN (Select Key_Message__c from Invisible_CLM_Key_Message__c) to ensure
    	//we stop the download of Key Messages to iRep that will not render due to inaccessible/invisible CLM Presentations
    	//VMOC on Key Messages (Global or Profile spec) - Where Id Not In (Select Key_Message_vod__c from Invisible_CLM_Key_Message__c where OwnerId = @@VOD_SF_USER_ID@@)
    	
    	if(invisibleKMObjSet!=null && invisibleKMObjSet.size() > 0){
    		insert new List<Invisible_CLM_Key_Message__c>(invisibleKMObjSet);
    	}
   	System.debug('After insert: invisibleKMObjSet  = ' + invisibleKMObjSet);
    }

/*
* This implementation takes a conservative approach to ensure best performance in downloads- 
* it gathers ALL downloadable KMs based on user accessible Products. Then, it gathers the 
* KMs (via Prezi --> slide) that should be visible to the end user and removes it from the
* map of total KMs accessible to the user. Each KM from this modified map is now added
* as an invisible KM and using a VMOC where clause, prevented from being downloading for the user
*/
    private void handleKeyMessageDownloads(){
    	//get accessible Product Ids for the User
    	Set<ID> userProductIds = CLMVisibilityManagerUtil.getUserMySetupProductIDs(UserInfo.getUserId()) ;
    	//get CLM Key Messages related to these Products
    	
    	System.debug('userProductIds = ' + userProductIds);
    	if(userProductIds==null || userProductIds.size() == 0){
    		return;//nothing to handle
    	}
    	
    	//Get all the CLM Key Messages that the User can download by way of accessible products
    	
    	Map<Id, Key_Message_vod__c> userCLMKeyMessageMap = new Map<Id, Key_Message_vod__c>
    														([Select Id, Name,Product_vod__c from Key_Message_vod__c 
    															where Product_vod__c in: userProductIds
    															and Active_vod__c = true 
    															and Media_File_Name_vod__c != NULL 
    															and PRODUCT_VOD__C != NULL]);
    	
    	System.debug('userCLMKeyMessageMap = ' + userCLMKeyMessageMap);
    	if(userCLMKeyMessageMap==null || userCLMKeyMessageMap.size() == 0){
    		return;//nothing to handle
    	}

    	List<CLM_Presentation_vod__c> userVisible =  (List<CLM_Presentation_vod__c>) new UserSpecificOps().getUserVisiblePrezis(false);
    	System.debug('userVisible = ' + userVisible);
    	Set<ID> visibleIDs = new Set<ID> ();
    	
    	for(CLM_Presentation_vod__c aPrezi: userVisible){
    		visibleIDs.add(aPrezi.Id);
    	}
    	System.debug('visibleIDs = ' + visibleIDs);
     	List<CLM_Presentation_vod__c> prezisToDownload = [SELECT Id, 
    															(SELECT Id,Key_Message_vod__c FROM Clm_Presentation_Slide_vod__r), 
    															(SELECT Id,Key_Message_vod__c FROM Clm_Presentation_Slide_2_vod__r) 
    														FROM Clm_Presentation_vod__c
    														where Id in: visibleIDs];
    	
    	
    	System.debug('prezisToDownload = ' + prezisToDownload);
    	//Add a reference to Key Messages that are associated to Non-visible CLM Presentations into Invisible_CLM_Key_Message__c
    	Set<Invisible_CLM_Key_Message__c> invisibleKMObjSet = new Set<Invisible_CLM_Key_Message__c> ();
    	if(prezisToDownload==null || prezisToDownload.size() == 0){
    		//nothing can be downloaded so block everything
    		for(ID aKMID: userCLMKeyMessageMap.keySet()){
     			invisibleKMObjSet.add(new Invisible_CLM_Key_Message__c (
    								OwnerId = UserInfo.getUserId(), 
    								Key_Message__c = aKMID, 
    								External_Id__c = UserInfo.getUserId() + '__' +aKMID ));   			
    		}
    	}
    	else{
	    	for(CLM_Presentation_vod__c aPrezi: prezisToDownload){
	    		for (Clm_Presentation_Slide_vod__c aSlide: aPrezi.Clm_Presentation_Slide_vod__r){
	    			userCLMKeyMessageMap.remove(aSlide.Key_Message_vod__c);
	    		}
	    		for (Clm_Presentation_Slide_vod__c aSlide: aPrezi.Clm_Presentation_Slide_2_vod__r){
	    			userCLMKeyMessageMap.remove(aSlide.Key_Message_vod__c);
	    		}
	    	}
 		  	//now what's left in userCLMKeyMessageMap is what should NOT download
 		  	for(ID aKMID: userCLMKeyMessageMap.keySet()){
     			invisibleKMObjSet.add(new Invisible_CLM_Key_Message__c (
    							OwnerId = UserInfo.getUserId(), 
    							Key_Message__c = aKMID, 
   								External_Id__c = UserInfo.getUserId() + '__' +aKMID ));   			
   			}
	    	
	     }
    	System.debug('userCLMKeyMessageMap after removals = ' + userCLMKeyMessageMap);
    	//first clean out all Invisible KMs owned by this user
    	List<Invisible_CLM_Key_Message__c> invKMObjsToDelete = [select Id from Invisible_CLM_Key_Message__c where OwnerId = :UserInfo.getUserId()];
    	
    	if(invKMObjsToDelete!=null && invKMObjsToDelete.size() > 0){
    		delete invKMObjsToDelete;
    	}
    	
	   	//Now Insert to this table - a VMOC will typically use a NOT IN (Select Key_Message__c from Invisible_CLM_Key_Message__c) to ensure
    	//we stop the download of Key Messages to iRep that will not render due to inaccessible/invisible CLM Presentations
    	//VMOC on Key Messages (Global or Profile spec) - Where Id Not In (Select Key_Message_vod__c from Invisible_CLM_Key_Message__c where OwnerId = @@VOD_SF_USER_ID@@)
    	
    	if(invisibleKMObjSet!=null && invisibleKMObjSet.size() > 0){
    		insert new List<Invisible_CLM_Key_Message__c>(invisibleKMObjSet);
    	}
    }    
    
    private void recordTransactions(){
    	if(transactionList!=null && transactionList.size() > 0){
    		insert transactionList;
    	}
    }
    private void doSystemResets(){
        originallyAvailablePrezis = new List<SelectOption> ();
        originallyAvailablePrezis.addAll(selectedCLMPrezis);
        selectedCLMPrezisBeforeChange = new List<SelectOption> ();
        selectedCLMPrezisBeforeChange.addAll(selectedCLMPrezis);
        newlyVisibleCLMIDs.clear();
    	newlyInvisibleCLMIDs.clear();
    	CLEAR_CACHE = true;
    	transactionList.clear();
  //  	clearVeevaCache();
    }
    
    /*
    * @methodDescription - Retrieves all available/non-accessible <code>Clm_Presentation_vod__c</code>
    * and returns the list in the form list of <code>SelectOption</code>
    */
    private List<SelectOption> getALLAvailableCLMPrezis(Boolean defaultOnly){
    	//Retrieve ALL CLM Presentations that are not already available to the user
    	List<Clm_Presentation_vod__c> defaultAvailablePrezis = [SELECT Name, Id FROM Clm_Presentation_vod__c
    													where Id not in: userAvailablePreziList
    													and Product_vod__c in: CLMVisibilityManagerUtil.getUserMySetupProductIDs(UserInfo.getUserId())] ;
    	System.debug('defaultAvailablePrezis = ' + defaultAvailablePrezis);
    	List<Clm_Presentation_vod__c> finallyAvailablePrezis = null;
    	if(defaultOnly){
    		return CLMVisibilityManagerUtil.convertToSelectOptions(defaultAvailablePrezis);
    	}
    	if(defaultAvailablePrezis!=null && defaultAvailablePrezis.size() > 0){
    		//prune this list based on CLM Visibility Configuration Objects (CVCs)
    		finallyAvailablePrezis = getFilteredAvailablePresentations(defaultAvailablePrezis);
    	}
     	return CLMVisibilityManagerUtil.convertToSelectOptions(finallyAvailablePrezis);
    }
    
    

    /*
    * @methodDescription - Filters down the CLM Prezi list based on CVCs for the logged in User
    */    
    private List<Clm_Presentation_vod__c> getFilteredAvailablePresentations(List<Clm_Presentation_vod__c> defaultPrezis){
    	//get the CVCs first - No CVC, no play
    	//get the Entity values - Users profile, profile id, user id & associated public groups
    	ID userID = UserInfo.getUserId();
    	ID profileID = UserInfo.getProfileId();
    	ID roleID = UserInfo.getUserRoleId();
    	//instantiate with the userId value since this will always be there
    	Set<ID> userAssociatedGroups = new Set<ID> {userID};
    	Set<ID> userAssociatedPublicGroups = new Set<ID> ();
    	    	
    	Set<ID> allRelatedIds = new Set<ID> ();
    	if(ALL_RELATED_TERRITORY_IDS!=null && ALL_RELATED_TERRITORY_IDS.size() > 0){
    		//add the direct and indirect territories (parents of direct terrs) this person belongs to
    		allRelatedIds.addAll(ALL_RELATED_TERRITORY_IDS);
    		
    	}
    	if(ALL_RELATED_ROLE_IDS!=null && ALL_RELATED_ROLE_IDS.size() > 0){
   		//add the direct and indirect roles (parents of direct role) this person belongs to
     		allRelatedIds.addAll(ALL_RELATED_ROLE_IDS);
    	}
    	//add the userid also as a related id, to cover the case where public group is directly created for users
    	System.debug('ALL_RELATED_TERRITORY_IDS = ' + ALL_RELATED_TERRITORY_IDS);
	   	System.debug('ALL_RELATED_ROLE_IDS = ' + ALL_RELATED_ROLE_IDS);
	   	System.debug('allRelatedIds = ' + allRelatedIds);
    	Map<Id, Group> userGroups = new Map<Id, Group> (
    											[Select Id, RelatedId 
    												from Group where RelatedId 
    												in: allRelatedIds
    											//	OR Id in: ALL_RELATED_PUBLIC_GROUP_IDS
    												]);	
    	if(userGroups!=null && userGroups.size() > 0){
    		userAssociatedGroups.addAll(userGroups.keySet());
    	//now that we have all the group ids to cover for any hierarchical Territory and Role Ids that make up Public Groups, 
    	//check and add any direct or indirect hierarchical Public Groups (Public Group inside a Public group inside a P...)
    	 //add the direct and indirect Public Groups (parents of direct Public Group or Public Groups corresponding to Terr or Role Hierarchy) this person belongs to
    	
			ALL_RELATED_PUBLIC_GROUP_IDS = CLMVisibilityManagerUtil.getParentPublicGroupIDs(userAssociatedGroups, userId);
		   	System.debug('ALL_RELATED_PUBLIC_GROUP_IDS = ' + ALL_RELATED_PUBLIC_GROUP_IDS);
		   	if(ALL_RELATED_PUBLIC_GROUP_IDS!=null){
		   		userAssociatedGroups.addAll(ALL_RELATED_PUBLIC_GROUP_IDS);
		   	}
    	}
    	List<Clm_Presentation_vod__c> finalAvailablePrezis = new List<Clm_Presentation_vod__c> ();
    	for(GroupMember aGrp: [SELECT GroupId, Group.Name, Id, SystemModstamp, UserOrGroupId FROM GroupMember
									where UserOrGroupId in :userAssociatedGroups]){
			userAssociatedPublicGroups.add(aGrp.GroupId);							
		}
    	
    	//create a set of External Ids for Entity values
    	Set<ID> cvcExternalIdSet = new Set<ID> ();
    	cvcExternalIdSet.add(userID);
    	cvcExternalIdSet.add(profileID);
    	cvcExternalIdSet.addAll(userAssociatedPublicGroups);
    	if(ALL_RELATED_PUBLIC_GROUP_IDS!=null){
    		cvcExternalIdSet.addAll(ALL_RELATED_PUBLIC_GROUP_IDS);
    	}
    	Set<String> availableClmPreziNames = new Set<String> ();
    	List<CLM_Visibility_Configuration__c> cvcList = [SELECT Entity_ID__c, Name, Entity_Type__c, External_Id__c, Id
    														, Available_CLM_Presentations_1__c, Available_CLM_Presentations_2__c
    														, Use_Custom_Criteria__c, Custom_Criteria__c, Exclusive_Criteria__c
    														, Active__c
    															FROM CLM_Visibility_Configuration__c 
    															WHERE External_Id__c in: cvcExternalIdSet
    															and Active__c = true];
    	
    	if(cvcList == null || cvcList.size() == 0) {
    		if(DEFAULT_NO_CVC_BEHAVIOR == 'DISPLAY_ALL' ){
 		   		return defaultPrezis;//NO CVCs, available list will be default
    		}
    		else{
    			return null;
    		}
     	}
    	
    	//get the CVCs based on External Ids
    	String whereClause = '' ;
    	Integer index = 0;
    	Boolean atleastOneCustomCriteria = false;
    	Boolean atleastOneNameCriteria = false;
	
    	for(CLM_Visibility_Configuration__c aCVC: cvcList){
    		if(aCVC.Use_Custom_Criteria__c){
    			if(aCVC.Exclusive_Criteria__c){
    				//then treat this as an override. This should only apply at User Entity level becuase otherwise
    				//we get into situations where the first record that comes up for comparison wins and results are
    				//unpredicatble
    				whereClause = ' ( ' + aCVC.Custom_Criteria__c + ' )';
    				atleastOneCustomCriteria = true;
    				break;
    			}
    			if(!atleastOneCustomCriteria){
    				atleastOneCustomCriteria = true;
    			}
    			else{
    				whereClause +=   ' OR ';//Always OR two custom conditions
     			}
     		//	whereClause += ' ( ' + String.escapeSingleQuotes(aCVC.Custom_Criteria__c) + ' )';
     			whereClause += ' ( ' + aCVC.Custom_Criteria__c + ' )';
    		}
    		else{
				String allAvailableCLMPrezis = aCVC.Available_CLM_Presentations_1__c + aCVC.Available_CLM_Presentations_2__c;
				availableClmPreziNames.addAll(allAvailableCLMPrezis.split(';'));
				atleastOneNameCriteria = true;
    		}
    	}
    	if(atleastOneCustomCriteria){
    		String clmPreziRetrieveQuery = 'SELECT Name, Id FROM Clm_Presentation_vod__c where Id in ';
    		Set<ID> defaultCLMPreziIDs = new Set<ID> ();
    		for(Clm_Presentation_vod__c aPrezi: defaultPrezis){
    			defaultCLMPreziIDs.add(aPrezi.ID);
    		}
    		clmPreziRetrieveQuery += ' :defaultCLMPreziIDs' +  ' AND (' + whereClause;//use the default list with AND criteria because you definitely don't want to go beyond default
    		if(atleastOneNameCriteria){
    			//(Name in: +')' + ')'
    			clmPreziRetrieveQuery += 'OR ( Name in :availableClmPreziNames )';
    		}
    		clmPreziRetrieveQuery += ')';
    		System.debug('Heres my ugly long DYnamic SOQL statement==> '  + clmPreziRetrieveQuery);
    		finalAvailablePrezis = (List<Clm_Presentation_vod__c>) Database.query(clmPreziRetrieveQuery);
    	}
    	else{
	    	//Filter out the CLM Presentations based on CVCs
	    	for(Clm_Presentation_vod__c aDefaultPrezi: defaultPrezis){
	    		if(availableClmPreziNames.contains(aDefaultPrezi.Name)){
	    			finalAvailablePrezis.add(aDefaultPrezi);
	    		}
	    	}
    	}
    	return finalAvailablePrezis;
    }
    /*
    * @methodDescription - Updates visibility to <code>Clm_Presentation_vod__c</code> for the end user
    */    
    private void updateCLMVisibility(List<SelectOption> selectedPrezis){
    	Set<ID> invisibleCopy = new Set<ID>();
		if(originallyAvailablePrezis!=null && originallyAvailablePrezis.size() > 0){
	    	removeExistingPreziVisbility(originallyAvailablePrezis);
	    	for(SelectOption aOption: originallyAvailablePrezis){
	    		newlyInvisibleCLMIDs.add(aOption.getValue());
	    	}
	    	if(newlyInvisibleCLMIDs!=null && newlyInvisibleCLMIDs.size() > 0){
	    		invisibleCopy.addAll(newlyInvisibleCLMIDs);	    		
	    	}
		}
		if(selectedPrezis!=null && selectedPrezis.size() > 0){
	    	addNewPreziVisibility(selectedPrezis);
	    	for(SelectOption aOption: selectedPrezis){
	    		newlyVisibleCLMIDs.add(aOption.getValue());
	    	}
		}
		if(newlyInvisibleCLMIDs!=null && newlyVisibleCLMIDs!=null){
			if(newlyVisibleCLMIDs.size() > 0){
				newlyInvisibleCLMIDs.removeAll(newlyVisibleCLMIDs);//now invisible only has what needs decrement
			}
			if(invisibleCopy.size() > 0){
				newlyVisibleCLMIDs.removeAll(invisibleCopy);//now visible only has what needs increment
			}
		}
    }

    /*
    * @methodDescription - Removes visibility to <code>Clm_Presentation_vod__c</code> for the end user
    */    

	private void removeExistingPreziVisbility(List<SelectOption> originalPrezis){
		Set<ID> preziIDSet = new Set<ID>();
		for(SelectOption aOption: originalPrezis){
			preziIDSet.add(aOption.getValue());
		}
		if(preziIDSet!=null && preziIDSet.size() > 0){
			List<Clm_Presentation_vod__Share> clmPreziShares = [Select Id , ParentId, UserOrGroupId
																  from Clm_Presentation_vod__Share
																  where ParentId in: preziIDSet
																  and UserOrGroupId = :UserInfo.getUserId()];
			if(clmPreziShares!=null && clmPreziShares.size() > 0){
				delete clmPreziShares;
			}
		}
	}
	
    /*
    * @methodDescription - Adds visibility to <code>Clm_Presentation_vod__c</code> for the end user
    */    
	private void addNewPreziVisibility(List<SelectOption> selectedPrezis){
    	List<Clm_Presentation_vod__Share> clmPreziShares = new List<Clm_Presentation_vod__Share>();
    	for(SelectOption aOption: selectedPrezis){
    		ID clmPreziID = aOption.getValue();
    		clmPreziShares.add(new Clm_Presentation_vod__Share(ParentId = clmPreziID, 
    															UserOrGroupId = UserInfo.getUserId(),
    															AccessLevel = CLMVisibilityManagerUtil.CLM_PREZI_DEFAULT_ACCESSLEVEL,
    															RowCause = Schema.Clm_Presentation_vod__Share.RowCause.VCVM_Manual_User_Selection__c));
    	}
	   	unchangedPrezisSet = new Set<ID> ();//reset this set
    	if(clmPreziShares!=null && clmPreziShares.size() > 0){
    		insert clmPreziShares;
    	}
	}

    /*
    * @classDescription - Inner class that respects sharing
    */    
	
    private with sharing Class UserSpecificOps {
	
	    private List<Object> getUserVisiblePrezis (Boolean returnSelectOptions){
	    	if(returnSelectOptions){
		    	return CLMVisibilityManagerUtil.convertToSelectOptions((List<Clm_Presentation_vod__c>)Database.query(CLMVisibilityManagerUtil.CLM_PREZI_USER_SPECIFIC_RETRIEVE_SOQL));
	    	}
	    	else{
	    		return Database.query(CLMVisibilityManagerUtil.CLM_PREZI_USER_SPECIFIC_RETRIEVE_SOQL);
	    	}
	    }
    }
    
    /*
    private  void markCLMKeyMessagesForDownload(){
    	Set<ID> idsToInclude = new Set<ID>();
    	idsToInclude.addAll(newlyInvisibleCLMIDs);
    	idsToInclude.addAll(newlyVisibleCLMIDs);
    	List<CLM_Presentation_vod__c> clmPrezisWorkedOn = [SELECT Id, 
    															(SELECT Id,Key_Message_vod__c, Key_Message_vod__r.CLM_Rep_Visibility_Count__c FROM Clm_Presentation_Slide_vod__r), 
    															(SELECT Id,Key_Message_vod__c, Key_Message_vod__r.CLM_Rep_Visibility_Count__c FROM Clm_Presentation_Slide_2_vod__r) 
    														FROM Clm_Presentation_vod__c
    														where Id in: idsToInclude];
    	Set<Key_Message_vod__c> keyMessagesToUpdate = new Set<Key_Message_vod__c>();
    	for(CLM_Presentation_vod__c aPrezi: clmPrezisWorkedOn){
    		List<Key_Message_vod__c> tmpList = null;
    		if(newlyVisibleCLMIDs.contains(aPrezi.Id)){ //if it contains in visible, no need to check in invisible
    			tmpList = enableContentDownload(aPrezi);
    		}
    		else{
    			tmpList = disableContentDownload(aPrezi);    			
    		}
    		if(tmpList!=null) {
    				keyMessagesToUpdate.addAll(tmpList);
    		}
    	}
    	if(keyMessagesToUpdate!=null && keyMessagesToUpdate.size() > 0 ){
    		update new List<Key_Message_vod__c>(keyMessagesToUpdate);//single DML to enable or disable Key Message flag	
    	}
    } 
    
    private List<Key_Message_vod__c> disableContentDownload(Clm_Presentation_vod__c aCLMPrezi){
    	transactionList.add(new CLM_Visibility_Manager_Transaction__c(User__c = UserInfo.getUserId(),
    																	Operation__c = 'Remove Visibility',
    																	CLM_Presentation__c = aCLMPrezi.Id));
    	return setKeyMessageDownloadFlag(aCLMPrezi, false);
     }
    
    private List<Key_Message_vod__c> enableContentDownload(Clm_Presentation_vod__c aCLMPrezi){
    	transactionList.add(new CLM_Visibility_Manager_Transaction__c(User__c = UserInfo.getUserId(),
    																	Operation__c = 'Add Visibility',
    																	CLM_Presentation__c = aCLMPrezi.Id));
    	return setKeyMessageDownloadFlag(aCLMPrezi, true);
    }
    
    private List<Key_Message_vod__c> setKeyMessageDownloadFlag(Clm_Presentation_vod__c aCLMPrezi, Boolean doIncrement){
    	List<Key_Message_vod__c> keyMsgs = new List<Key_Message_vod__c> ();
    	Integer counter = 0;
	   	List<Invisible_CLM_Key_Message__c> invisibleKMs = new List<Invisible_CLM_Key_Message__c> ();
     	
    	for(Clm_Presentation_Slide_vod__c aSlide: aCLMPrezi.Clm_Presentation_Slide_vod__r){
    		if(aSlide.Key_Message_vod__r.CLM_Rep_Visibility_Count__c==null){
    			counter = (doIncrement) ? 1 : 0;
    		}
    		else if(doIncrement){
    				counter = (Integer) aSlide.Key_Message_vod__r.CLM_Rep_Visibility_Count__c + 1; 
    		}
    		else if(!doIncrement && aSlide.Key_Message_vod__r.CLM_Rep_Visibility_Count__c!=0 ){
    			counter = (Integer) aSlide.Key_Message_vod__r.CLM_Rep_Visibility_Count__c - 1;    			
    		}
    		else {
    			continue;//nothing to update if the value is already zero and needs to be further decremented
    			//this may be the case if no visibility exists and user tries to add first time
    		}
    		keyMsgs.add(new Key_Message_vod__c(Id = aSlide.Key_Message_vod__c, CLM_Rep_Visibility_Count__c = counter));
    	}
     	return keyMsgs;
    }
    
    public void clearVeevaCache(){
    	message = 'Clearing Veeva cache..';
    	CLEAR_CACHE = false;
	   	HttpRequest req = new HttpRequest();
	    req.setEndpoint('/apex/ClearVeevaCacheVFPage');
	    req.setMethod('GET');
	    Http ht = new Http();
     	HTTPResponse res = ht.send(req);
     	System.debug('HTTP Response::::::!!!!' + res.getBody());   
    }
    public void enablePanelRendering(){
    	RENDER_PANEL = true;
    	message = 'Panel rendering enabled..' + RENDER_PANEL;
    	
    }
    */
    
}