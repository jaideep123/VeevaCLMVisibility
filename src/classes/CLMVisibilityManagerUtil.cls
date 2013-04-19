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
	* @methodDescription: Returns a <code>List<ID></code> for <code>Product_vod__c</code>
	* available to the User
	*/
    public static Set<ID> getUserMySetupProductIDs(ID userID){
    	
    	Set<ID> productIDSet = new Set<ID>();
    	
    	List<My_Setup_Products_vod__c> mySetupList = [select Id, Product_vod__c, OwnerId 
    									  from My_Setup_Products_vod__c
    									  where OwnerId =: userId];
    	for(My_Setup_Products_vod__c aSetup: mySetupList){
    		productIDSet.add(aSetup.Product_vod__c);
    	}
       	return productIDSet;
    }


}