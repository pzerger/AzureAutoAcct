workflow Get-OMSsearchQuery
{
	$Alert = $false
	
	#Get our Connection Objects
       $OMSConnection = Get-AutomationConnection -Name 'OMSConnection'
	$ADConnection = Get-AutomationConnection -Name 'ADConnection'

	#Create our Token	
	$UserName = $ADConnection.UserName + "@" + $ADConnection.AzureADDomain
	$ADConn = @{"Username"=$Username;"AzureADDomain"=$ADConnection.AzureADDomain;"Password"=$ADConnection.Password;"APPIdURI"=$ADConnection.AppIdURI;}
	$Token = Get-AzureADToken -Connection $ADConn
	
	#Use our OMSConnection object to retrieve our OMS information
	$WorkSpace = $OMSConnection.Workspace
	$SubID = $OMSConnection.SubscriptionID
	$Region = $OMSConnection.Region
	$APIVersion = $OMSConnection.APIVersion
	
	#Define our search query
	$Query = 'Type=Event EventLog=System EventID=7036'
	Write-Output "*** Executing query *** " $Query

	#Get our OMS Search query results for our Honeypot Account
	$Results = Search-OMSWorkspace -Token $Token -Subscription $SubID -Workspace $Workspace -Region $Region -APIVersion "2015-03-20" -Query $Query
	#Uncomment the next line if you want to see all results returned
	#$Results
	$Accounts = $Results.TargetUserName
	
	#Check our Honeypot Account
	foreach ($Account in $Accounts)
		{
			if($Account -eq "LocalAdmin")
          	{
			  $Alert = $true
			  $AccountName = $Account
		  	}
		} 
	#We have a match
	if($Alert -eq $true)
	{
		Write-Output "Raising Alert! Logon attempt found for account: $AccountName"
	}
	#We don't have a match
	else
		{
			Write-Output "These are not the droids you are looking for!"
		}
 }