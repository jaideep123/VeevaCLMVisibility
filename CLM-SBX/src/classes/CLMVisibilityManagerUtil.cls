/**
* @author - Murugesh Naidu, Veeva Systems Inc
* @className - CLMVisibilityManagerUtil.cls
* @description - Utility class for CLM Visibility Manager
* @createdate - March 18th, 2012
*
*/

public class CLMVisibilityManagerUtil {
	
	public static final String CLM_PREZI_DEFAULT_ACCESSLEVEL = 'Read';
	public static final String CLM_PREZI_GLOBAL_RETRIEVE_SOQL = 'SELECT Name, Id FROM Clm_Presentation_vod__c';
	public static final String CLM_PREZI_USER_SPECIFIC_RETRIEVE_SOQL = 'SELECT Name, Id FROM Clm_Presentation_vod__c';
	public static final String CLM_PREZI_SUCCESS_MSG = 'CLM Presentation visibility has now been successfully updated for you! ';
	public static final String CLM_PREZI_ERROR_MSG = 'There was an error updating visibility. All existing visibilities will still be maintained. ';
	public static final String CLM_PREZI_NOCHANGE_MSG = 'Nothing to update. Please perform a legitimate action. Thanks! ';
	public static final String CLM_PREZI_EXCEPTION_INTRO_MSG = 'Error Processing request. No changes to visibility have been done. Please refresh to retry or contact your Administrator with the error details below.';
	public static final String CLM_PREZI_EXCEPTION_ADMIN_NOT_ALLOWED = 'Your profile already has access to All CLM Presentations and you may not use this tool. This tool can only be used by users that do not have View All or Modify All Permission.';
	public static  Boolean CLM_PREZI_NO_CHANGE = true;
	

	/*
	* @methodDescription: Converts a <code>List<Clm_Presentation_vod__c></code> to <code>List<SelectOption></code>
	*/

    public static List<SelectOption> convertToSelectOptions(List<Clm_Presentation_vod__c> clmPresentatios){
	   	List<SelectOption> selectOptionsList = new List<SelectOption> () ;
	        if(clmPresentatios!=null){
		        for ( Clm_Presentation_vod__c c : clmPresentatios ) {
		            selectOptionsList.add(new SelectOption(c.Id, c.Name));
		        }
	        }
	        return selectOptionsList;
    }
    
	/*
	* @methodDescription: Converts a <code>List<Clm_Presentation_vod__c></code> to <code>List<SelectOption></code>
	*/

    public static List<SelectOption> convertToSelectOptions(List<User> users){
	   	List<SelectOption> selectOptionsList = new List<SelectOption> () ;
	        if(users!=null){
		        for ( User c : users ) {
		            selectOptionsList.add(new SelectOption(c.Id, c.FirstName + ' ' + c.Lastname));
		        }
	        }
	        return selectOptionsList;
    }
    
	/*
	* @methodDescription: Converts a <code>List<Clm_Presentation_vod__c></code> to <code>List<SelectOption></code>
	*/

    public static List<SelectOption> convertToSelectOptions(List<Profile> profiles){
	   	List<SelectOption> selectOptionsList = new List<SelectOption> () ;
	        if(profiles!=null){
		        for ( Profile c : profiles ) {
		            selectOptionsList.add(new SelectOption(c.Id, c.Name));
		        }
	        }
	        return selectOptionsList;
    }
    
	/*
	* @methodDescription: Returns a <code>List<ID></code> for <code>Product_vod__c</code>
	* available to the User
	*/
    public static Set<ID> getUserMySetupProductIDs(ID userID){
    	
    	Set<ID> productIDSet = new Set<ID>();
    	
    	List<My_Setup_Products_vod__c> mySetupList = [select Id, Product_vod__c, OwnerId 
    									  from My_Setup_Products_vod__c
    									  where OwnerId =: userId
    									  and Product_vod__c != ''];
    	for(My_Setup_Products_vod__c aSetup: mySetupList){
    		productIDSet.add(aSetup.Product_vod__c);
    	}
       	return productIDSet;
    }

	/*
	* @methodDescription: Returns false if eny of the entity names is not valid. If all entities are valid, 
	* Returns true and updates the passed <code>List<CLM_Visibility_Configuration__c></code> with the valid entity Ids.
	*/
    public static Boolean allValidEntities(List<CLM_Visibility_Configuration__c> cvcList){
    	if(cvcList==null || cvcList.size() == 0){
    		return false;
    	}
    	List<String> userNameList = new List<String>();
    	List<String> profileNameList = new List<String>();
    	List<String> grpNameList = new List<String>();
    	Integer totalInputSize = 0;
    	Integer totalOutputSize = 0;
    	Boolean isValid = false;
    	for(CLM_Visibility_Configuration__c aCVC: cvcList){
    		if(aCVC.Entity_Type__c == 'Public Group'){
    			grpNameList.add(aCVC.Name);
    		}
    		if(aCVC.Entity_Type__c == 'Profile'){
    			profileNameList.add(aCVC.Name);
    		}
    		if(aCVC.Entity_Type__c == 'User'){
    			userNameList.add(aCVC.Name);
    		}
    	}
    	totalInputSize = grpNameList.size() + profileNameList.size() + userNameList.size();
    	List<User> usrList = [select Id, Name, UserName from User where UserName in:userNameList ];
    	List<Profile> prflList = [select Id, Name from Profile where name in:profileNameList ];
    	List<Group> grpList = [select Id, Name from Group where name in:grpNameList ];
    	totalOutputSize += (usrList!=null) ? usrList.size() : 0;
    	totalOutputSize += (prflList!=null) ? prflList.size() : 0;
    	totalOutputSize += (grpList!=null) ? grpList.size() : 0;
    	
    	if(totalInputSize==totalOutputSize){
    		isValid = true;
	    	Map<String, ID> usrMap = new Map<String, ID>();
	    	Map<String, ID> prflMap = new Map<String, ID>();
	    	Map<String, ID> grpMap = new Map<String, ID>();

    		for(User aUsr: usrList){
    			usrMap.put(aUsr.UserName, aUsr.Id);
    		}
    		for(Profile aPrfl: prflList){
    			prflMap.put(aPrfl.Name, aPrfl.Id);
    		}
    		for(Group aGrp: grpList){
    			grpMap.put(aGrp.Name, aGrp.Id);
    		}
    		
    		for(CLM_Visibility_Configuration__c aCVC: cvcList){
    			if(aCVC.Entity_Type__c == 'Profile'){
       				aCVC.Entity_ID__c = prflMap.get(aCVC.Name);
    			}
    			if(aCVC.Entity_Type__c == 'User'){
       				aCVC.Entity_ID__c = usrMap.get(aCVC.Name);
    			}
    			if(aCVC.Entity_Type__c == 'Public Group'){
       				aCVC.Entity_ID__c = grpMap.get(aCVC.Name);
    			}
     		}
    	}
    	
    	return isValid;
    	
    }    
    
    /*
    * @description - This method will return a Set of IDs that includes
    * 1. All direct territories that the user belongs to
    * 2. All parent and grand parents traversed through the top till there is no parent
    */
    public static Set<ID> getParentTerritoryIDs(ID userID){
    	List<UserTerritory> userTerritories = [Select Id, TerritoryId, UserId 
    											from UserTerritory
												where UserId = :userID];
		if(userTerritories==null || userTerritories.size() == 0 ){
			return null;
		}
		Set<ID> allRelatedTerrIDs = new Set<ID> ();
		Set<ID> directTerrIds = new Set<ID> ();
		for(UserTerritory ut: userTerritories){
			directTerrIds.add(ut.TerritoryId);
		}
		//load up ALL Territories
		Map<Id, Territory> territoryMap = new Map <ID, Territory> ([Select Id, ParentTerritoryId, Name
											from Territory]);
		
		for(ID terrId: directTerrIds){
			allRelatedTerrIDs.add(terrId);
			Territory aTerr = territoryMap.get(terrID);
			while(aTerr.ParentTerritoryId!=null){//if there is no Parent, then it should drop out of the loop
				allRelatedTerrIDs.add(aTerr.ParentTerritoryId);//record all related Terr Ids in this set
				aTerr = territoryMap.get(aTerr.ParentTerritoryId);//this will now change the reference to th Parent Territory
			}
		}
		return 	allRelatedTerrIDs	;						
    }

   /*
    * @description - This method will return a Set of IDs that includes
    * 1. All direct territories that the user belongs to
    * 2. All parent and grand parents traversed through the top till there is no parent
    */
    public static Set<ID> getParentPublicGroupIDs(Set<ID> groupIds, ID userId){
    	List<GroupMember> userGroupMembers = [Select Id, GroupId, Group.Type, UserOrGroupId 
    											from GroupMember
												where  (UserOrGroupId in: groupIds OR UserOrGroupId =: userId)
												and Group.Type = 'Regular'];
		if(userGroupMembers==null || userGroupMembers.size() == 0 ){
			return null;
		}
		Set<ID> allRelatedPubGrpIDs = new Set<ID> ();
		Set<ID> directPubGrpIds = new Set<ID> ();
		for(GroupMember gm: userGroupMembers){
			directPubGrpIds.add(gm.GroupId);
		}
		//load up ALL GroupMembers that are related to Public Groups
		List<GroupMember> groupMembers = new List <GroupMember> ([Select Id, GroupId, Group.Type, UserOrGroupId 
    																		from GroupMember
																			where Group.Type = 'Regular']);
		
		Map<Id, GroupMember> userGrpIdToGroupMember = new Map<Id, GroupMember> ();
		for(GroupMember aMem: groupMembers){
			userGrpIdToGroupMember.put(aMem.UserOrGroupId, aMem);
		}
		
		for(GroupMember grpMember: userGroupMembers){
			allRelatedPubGrpIDs.add(grpMember.GroupId);//add the direct Group Id to relatedId list
			GroupMember aGrpMem = userGrpIdToGroupMember.get(grpMember.GroupId);//Check if this Group itself belongs to another Public Group
			while(aGrpMem!=null){//if there is no associated Public Group, then it should drop out of the loop
				allRelatedPubGrpIDs.add(aGrpMem.GroupId);//record all related Terr Ids in this set
				aGrpMem = userGrpIdToGroupMember.get(aGrpMem.GroupId);//this will now change the reference to th Parent Group, if any
			}
		}
		return 	allRelatedPubGrpIDs	;						
    }

    /*
    * @description - This method will return a Set of IDs that includes
    * 1. All direct roles that the user belongs to
    * 2. All parent and grand parents roles traversed through the top till there is no parent
    */
    public static Set<ID> getParentRoleIDs(ID roleId){
		
		if(roleId==null){
			return null;
		}
		Set<ID> allRelatedRoleIDs = new Set<ID> ();
		//load up ALL Roles
		Map<Id, UserRole> roleMap = new Map <ID, UserRole> ([Select Id, ParentRoleId, Name
											from UserRole]);
		if(roleMap == null || roleMap.size() == 0 ){
			return null;
		}
		Id tmpRoleId = roleId;
		do{
			
			UserRole theRole = roleMap.get(tmpRoleId);
			allRelatedRoleIDs.add(theRole.Id);
			tmpRoleId = theRole.ParentRoleId;
			
		}while (tmpRoleId!=null);
		
		return 	allRelatedRoleIDs	;						
    }


}