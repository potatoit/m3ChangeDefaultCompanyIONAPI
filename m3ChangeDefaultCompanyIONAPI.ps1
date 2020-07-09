# m3ChangeDefaultCompany
#
#	this script will change the default company/division of user(s) in MNS150 (it will also add them to that company/division in MNS151)
#
# Arguments:
# 	-IONAPI <path to .ionapi file>
#	-Company <company>
#	-Division <division>
#	-Users [m3Username1,m3Username2,...]
#			A comma seperated list of M3 usernames
#	-UserFile <path to text file>
#			A text file with each m3 username on a new line
#	-AllUsers
#
#	History
#		20200518	- corrected expiry token call

param([Parameter(Mandatory = $true)][string]$IONAPI, [Parameter(Mandatory = $true)][string]$Company, [Parameter(Mandatory = $true)][string]$Division, [Parameter(Mandatory = $false)][string]$Users, [Parameter(Mandatory = $false)][string]$UserFile, [Parameter(Mandatory = $false)][switch]$AllUsers = $false)


# may need to change this in the future; not explicitly setting it causes issues at the moment
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12


function CallExport
{
	Param($Url, $token)
	$result = $null
	
	$uri = [System.Uri] $Url
	
	$request = [System.Net.HttpWebRequest]::CreateHttp($uri)
	#$request.ContentType = "application/json; charset=UTF-8"
	$request.Accept = "application/json"
	$request.Method = "GET"
	$request.PreAuthenticate = $true
	$request.UseDefaultCredentials = $false
	$request.Headers.Add("Authorization", "Bearer $token")
	$request.Proxy = [System.Net.WebRequest]::DefaultWebProxy
	$request.Credentials = $null
	
	try
	{
		$response = $request.GetResponse()
		
		if($response)
		{
			$responseStream = $response.GetResponseStream()
			if($responseStream)
			{
				$streamReader = New-Object -TypeName System.IO.StreamReader -ArgumentList $responseStream
				if($streamReader)
				{
					$result = $streamReader.ReadToEnd() | ConvertFrom-Json
				}
				else
				{
					Write-Output "No StreamReader"
				}
				$responseStream.Close()
			}
			else
			{
				Write-Output "No Response Stream"
			}
		}
		else
		{
			Write-Output "No Response"
		}
	}
	catch
	{
		Write-Output $_
	}

	return $result
}

# get bearer token
function GetBearer
{
	Param($oauthPath, $clientID, $clientSecret, $userName, $password)
	$result = $null
	
    $Uri = $oauthPath

    $Body = @{
        grant_type = 'password'
        username = "$userName"
        password = "$password"
        client_id = "$clientID"
        client_secret = "$clientSecret"
    }

    try
    {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $AuthResult = Invoke-RestMethod -Method Post -Uri $Uri -Body $Body
    }
    catch 
    {
     Write-Output "$_"
    }

    $result = $AuthResult.access_token

	return $result
}

function ExpireToken
{
	Param($oauthPath, $token)
	$result = $null
	
    $Uri = $oauthPath

    try
    {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $AuthResult = Invoke-RestMethod -Method Post -Uri $Uri -Body "token=$token"
    }
    catch 
    {
     Write-Output "$_"
    }

    $result = $AuthResult.access_token

	return $result
}

$ionAPIFile = Get-Content -Raw -Path $IONAPI | ConvertFrom-Json

if($ionAPIFile)
{
    $pu = $ionAPIFile.pu
    $ot = $ionAPIFile.ot
	$or = $ionAPIFile.or
    $ionAPIAuthUrl = "$pu$ot"
    $ClientID = $ionAPIFile.ci
    $ClientSecret = $ionAPIFile.cs
    $Username = $ionAPIFile.saak
    $Password = $ionAPIFile.sask
    $ionapiBaseURL = $ionAPIFile.iu
    $tenant = $ionAPIFile.ti
	$ionAPIRevokeUrl = "$pu$or"

    $token = GetBearer $ionAPIAuthUrl $ClientID $ClientSecret $Username $Password

    $URL = "$ionapiBaseURL/$tenant/M3/m3api-rest/execute"

    $lstUserDataBaseURL = $URL + "/MNS150MI/LstUserData/"
    $chgDefaultValueBaseURL = $URL + "/MNS150MI/ChgDefaultValue/"
    $addUserPerCmpDivBaseURL = $URL + "/MNS150MI/AddUsrPerCmpDiv/"

    if($token)
    {
	    Write-Output "We have a token"
	
	    if($Users)
	    {
		    if($Users.IndexOf(",") -ne -1)
		    {
			    $userList = $User.Split(",").Trim()
		    }
		    else
		    {
			    $userList = @($Users)
		    }
	    }
	    elseif($UserFile)
	    {
		    $userList = Get-Content -Path $UserFile
	    }
	    elseif($AllUsers)
	    {
		    $completelstUserDataBaseURL = $lstUserDataBaseURL + ";maxrecs=0"
		
		    $lstUserDataResult = CallExport $completelstUserDataBaseURL $token
		
		    $userList = ($lstUserDataResult.MIRecord.NameValue | Where-Object { $_.Name -eq 'USID' }).Value.Trim()
	    }
	
	
	    if($userList.Length -gt 0)
	    {
		    for($i = 0; $i -lt $userList.Length; $i++)
		    {
			    $progress = ($i / $userList.Length) * 100
			
			    $currentUserName = $userList[$i]
			    $chgDefaultValueFinalURL = $chgDefaultValueBaseURL + "?USID=$currentUserName&CONO=$Company&DIVI=$Division"

			    $addUserPerCmpDivFinalURL = $addUserPerCmpDivBaseURL + "?USID=$currentUserName&CONO=$Company&DIVI=$Division"
			
			    Write-Progress -Activity "Changing $currentUserName CONO to $Company, DIVI to $Division" -Status "$progress% Complete:" -PercentComplete $progress
			    Write-Output $addUserPerCmpDivFinalURL
			    $callResult = CallExport $addUserPerCmpDivFinalURL $token
			
			    Write-Output $chgDefaultValueFinalURL
			    $callResult = CallExport $chgDefaultValueFinalURL $token
		    }
	    }


        ExpireToken $ionAPIRevokeUrl $token
    }
    else
    {
	    Write-Output "Failed to get token"
    }
}
else
{
    Write-Output "Failed to open ionapi file"
}


