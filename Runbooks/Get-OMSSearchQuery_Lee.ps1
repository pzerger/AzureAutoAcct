workflow Get-OMSSearchQuery_Lee
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
	$Query = 'Type=Event EventLevelName=information Source="OMSAutomation"'
	Write-Output "*** Executing query *** " $Query

	#Get our OMS Search query results for our Honeypot Account
	$Results = Search-OMSWorkspace -Token $Token -Subscription $SubID -Workspace $Workspace -Region $Region -APIVersion "2015-03-20" -Query $Query
	Write-Output $Results
 
	
	
}