# m3ChangeDefaultCompanyIONAPI

This script will change the default company/division of user(s) in MNS150 (it will also add them to that company/division in MNS151)  

Arguments:  
 	-IONAPI <path to .ionapi file>  
	-Company <company>  
	-Division <division>  
	-Users [m3Username1,m3Username2,...]  
			A comma seperated list of M3 usernames  
	-UserFile <path to text file>  
			A text file with each m3 username on a new line  
	-AllUsers  
  
The .ionapi file should be created as a background application with a valid service account.  
  
History  
		20200518	- corrected expiry token call  
