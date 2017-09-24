Param(
    [Parameter(Mandatory=$true)][PSCredential]$SCCMCred,
    [Parameter(Mandatory=$true)][string]$CollectionName,
    [Parameter(Mandatory=$true)][string]$ComputerName
    )
#Retrieve SCCM site server name from Azure Automation variable
$SiteServer = Get-AutomationVariable SCCMSiteServer
Write-Verbose "SCCM Site Server: '$SiteServer'"
Write-Verbose "Connecting to SCCM Site server using user name '$($SCCMCred.UserName)'."

#Query site server WMI to get site code and SMS provider computer name
$ProviderLocation = Get-WmiObject -Namespace "Root\SMS" -Query "Select * from SMS_ProviderLocation" -Credential $SCCMCred -ComputerName $SiteServer
$SiteCode = $ProviderLocation.SiteCode
$SMSProvider = $ProviderLocation.Machine
Write-Verbose "SCCM Site Code: '$SiteCode'."
Write-Verbose "SMS Provider computer name: '$SMSProvider'."

#Get the collection WMI object
$Collection = Get-WmiObject -Namespace "Root\SMS\Site_$SiteCOde" -Query "Select * from SMS_Collection Where Name = '$CollectionName'" -Credential $SCCMCred -ComputerName $SMSProvider
If ($Collection){
    $CollectionID = $Collection.CollectionID
    Write-Verbose "collection '$CollectionName' ID is: '$CollectionID'"
} else {
    throw "Unable to find collection with name '$CollectionName'. Unable to continue"
    Exit -1
}

#Get the computer resource
$Resource = Get-WmiObject -ComputerName $SMSProvider -Namespace "Root\SMS\Site_$SiteCode" -Class "SMS_R_System" -Filter "Name = '$ComputerName'" -Credential $SCCMCred | select name,resourceid
If ($Resource){
    $ResourceID = $Resource.resourceid
    Write-Verbose "Resource ID for computer '$ComputerName' is: '$ResourceID'"
} else {
    throw "Unable to find computer resource for '$ComputerName'. Unable to continue."
    Exit -1
}

#Create static membership rule for collection
Write-Verbose "Adding computer '$ComputerName' to collection '$CollectionName' by creating a new static membership rule."
$ruleClass = Get-WmiObject -List -ComputerName "$SMSProvider" -Namespace "Root\SMS\Site_$Sitecode" -Credential $SCCMCred -class "SMS_CollectionRuleDirect"
$newRule = $ruleClass.CreateInstance()     
$newRule.RuleName = $($Resource.name)
$newRule.ResourceClassName = "SMS_R_System"       
$newRule.ResourceID = $($Resource.resourceid)
$AddResult = ($Collection.AddMembershipRule($newRule)).ReturnValue

If ($AddResult -eq 0)
{
    Write-Output "Collection `"$CollectionName`" direct membership rule successfully created for computer `"$ComputerName`", requesting refresh now."
    $RefreshResult = ($Collection.RequestRefresh()).ReturnValue
    If ($RefreshResult -eq 0)
    {
        Write-Output "Collection refresh successfully requested for `"$CollectionName`"."
    } else {
        Write-Error "Failed to request collection refresh for `"$CollectionName`"."
    }
} else {
    Write-Error "Failed to add computer '$ComputerName' as a direct member for collection `"$CollectionName`"."
}
