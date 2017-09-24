<#
===========================================================================
Created on:   	30/10/2015
Created by:   	Tao Yang
Filename:     	Create-ADUserAccount.ps1
-------------------------------------------------------------------------
Description:
This script is an Azure Automation PowerShell runbook that can be used to
Create new user accounts on On-Prem AD via Hybrid Workers

Required PS Modules (must also be deployed to hybrid workers manually):
SharePointSDK (https://www.powershellgallery.com/packages/SharePointSDK/)
SendEmail (https://www.powershellgallery.com/packages/SendEmail/)

Required Azure Automation Assets:
Variable "LabDomainController": The computer name of the domain controller

Variable "LabADUserOU": The Distinguished Name of the OU or Container that
the user account will be created under (i.e. CN=Users,DC=Domain,DC=com)

Variable "NewADUserSPList": The display name of the SharePoint list for
the new users request.

Connection "SMTPNotification": the "SMTPServerConnection" connection object
that contains the connection information for the SMTP server.

Connection "SPRequestsSite": the SharePointSDK connection object that
contains the connection information for the SharePoint site.
===========================================================================
#>
Param(
[Parameter(Mandatory=$true)][PSCredential]$ADCred,
[Parameter(Mandatory=$true)][String]$FirstName,
[Parameter(Mandatory=$true)][String]$LastName,
[Parameter(Mandatory=$false)][String]$Title,
[Parameter(Mandatory=$false)][String]$Description,
[Parameter(Mandatory=$false)][String]$Department,
[Parameter(Mandatory=$false)][String]$Company,
[Parameter(Mandatory=$false)][String]$Location,
[Parameter(Mandatory=$false)][String]$Telephone,
[Parameter(Mandatory=$false)][String]$RequesterEmail,
[Parameter(Mandatory=$false)][int]$ListItemID
)

#region functions
function Generate-UserID
{
	[CmdletBinding()]
	PARAM (
		[Parameter(Mandatory=$true)][String]$FirstName,
		[Parameter(Mandatory=$true)][String]$LastName
	)
	$strID = "$FirstName`.$LastName"
	#The User ID cannot be more than 20 characters long. Need to be shortened if that's the case
	if ($strID.length -gt 20)
	{
		if ($LastName.length -ge 10)
		{
			$LastName = $LastName.substring(0,9)
			$strID = "$FirstName`.$LastName"
		}
		#if the ID is still longer than 20 characters, chop the first name
		#remember leave 1 character for "."
		if ($strID.length -gt 20)
		{
			$FirstName = $FirstName.substring(0,10)
			$strID = "$FirstName`.$LastName"
		}
	}
	$strID
}

function Generate-TempPassowrd
{
    [CmdletBinding()]
	PARAM (
		[Parameter(Mandatory=$true)][int]$Length,
		[Parameter(Mandatory=$true)][int]$NumberOfSpecialCharacters
	)
    Add-Type -Assembly System.Web
    [Web.Security.Membership]::GeneratePassword($length,$NumberOfSpecialCharacters)
}

#endregion

Write-Verbose "retriving automation variables"
$DomainController = Get-AutomationVariable LabDomainController
$UserOU = Get-AutomationVariable LabADUserOU
If ($RequesterEmail.length -gt 0)
{
    $SMTPConnection = Get-AutomationConnection SMTPNotification
}
If ($ListItemID)
{
    $SPConnection = Get-AutomationConnection SPRequestsSite
    $SPListName = Get-AutomationVariable NewADUserSPList
    Write-Verbose "SharePoint Site URL: '$($SPConnection.SharePointSiteURL)'"
    Write-Verbose "SharePoint List Name: '$SPListName'"
}
Write-Verbose "Domain Controller: $DomainController"
Write-Verbose "User OU: '$UserOU'."

#Connect to domain using ADSI
$DomainDN = $(([adsisearcher]$DomainController).Searchroot.path)
$Domain = New-Object -TypeName System.DirectoryServices.DirectoryEntry -ArgumentList $DomainDN,$($ADCred.UserName),$($ADCred.GetNetworkCredential().password)
Write-Verbose "Domain DN: '$DomainDN'."
#Get Domain FQDN
$arrDNs = $Domain.distinguishedName.Replace("DC=","").Split(",")
$DomainFQDN = [string]::Join(".", $arrDNs)
Write-Verbose "Domain FQDN: '$DomainFQDN'."

#Create User account
$UserName = Generate-UserID $FirstName $LastName

$ADLocation = $objUser.ADLocation
$searcher = New-Object System.DirectoryServices.DirectorySearcher
$searcher.SearchRoot = $Domain
$searcher.filter = "(&(objectCategory=person)(givenName=$FirstName)(sn=$LastName))"
$searcher.SearchScope = "subTree"
$userResult = $searcher.findOne()

#Check if the user is found in AD
if ($userResult -ne $null)
{
	$user = $userResult.GetDirectoryEntry()
	$sAMAccountName = $user.sAMAccountName

	Write-Error "AD Account creation failed: $FirstName $Surname already in AD, the ID is $sAMAccountName"

} else {
	$UserName = Generate-UserID -FirstName $FirstName -LastName $LastName

	#start creating the user AD account
	Write-Verbose "Creating account for '$FirstName $LastName'. User ID is: '$UserName'."
	$OU = New-Object DirectoryServices.DirectoryEntry("LDAP://$UserOU",$($ADCred.UserName),$($ADCred.GetNetworkCredential().password))
		
	$user = $OU.Create("User", "CN=$UserName")
	$user.SetInfo() | out-null
	Write-Verbose "Setting sAMAccountName for '$FirstName $LastName' to $UserName"
	$user.put("sAMAccountName", $UserName)
	$user.SetInfo() | out-null
	Write-Verbose "Setting password for '$FirstName $LastName'"
    $TempPassword = Generate-TempPassowrd -Length 8 -NumberOfSpecialCharacters 2
	$user.SetPassword($TempPassword)
    Write-Verbose "Saving User account."
	$user.SetInfo() | out-null
	Write-Verbose "Setting additional properties for ID '$UserName'"
    $UPN = "$UserName`@$DomainFQDN"
    Write-Verbose "UPN: '$UPN'."
	$user.put("userprincipalname", $UPN)
	$user.sn = $LastName
	$user.givenName =$FirstName
	$user.displayName = "$FirstName $LastName"
    Write-Verbose "Setting mandatory attributes."
	$user.SetInfo()
    If ($Description) {$user.Description = $Description}
    If ($Title) {$user.title = $Title}
    If ($Location) {$user.l = $Location}
	If ($Company) {$user.company = $Company}
    If ($Department) {$user.department = $Department}
	If ($Telephone) {$user.ipPhone = $Telephone}
	Write-Verbose "Updating user ID with additional optional attributes."
	$user.SetInfo() | out-null
	$user.pwdLastSet = 0
	$user.userAccountControl = 512
    Write-Verbose "Set 'User must change password at next logon' flag and enable user ID."
	$user.SetInfo() | out-null
    $Now = (Get-Date).ToUniversalTime()
    #Email the new user ID credential if the requester's email is specified
    If ($RequesterEmail)
    {
        Write-Verbose "Emailing the new user credential to the requester '$RequesterEmail'."
        $Subject = "AD User ID Creation for '$FirstName $LastName'"
$Body = @"
Hello,

this is a system generated message. The user id for '$FirstName $LastName' has been created.

Domain Name - $DomainFQDN
User Name - $UserName
Temporary Password - $TempPassword

The user must change the password at the first logon.

Best Regards,
Azure Automation
"@
Send-Email `
	-Body $Body `
	-HTMLBody $false `
	-SMTPSettings $SMTPConnection `
	-Subject $Subject `
	-To $RequesterEmail

    }
	if ($Error.Count -eq 0)
	{
		Write-Output "AD account `"$UserName`" is created!"
        Write-Output "Temporary password is `"$TempPassword`". User must change password during the first logon."
        If ($ListItemID)
        {
            Write-Verbose "Updating SharePoint list item"
            $ListFields = Get-SPListFields -SPConnection $SPConnection -ListName $SPListName
            $UserIDFieldInternalName = ($ListFields | Where-Object {$_.Title -ieq 'User ID' -and $_.ReadOnlyField -eq $false}).InternalName
            $StatusFieldInternalName = ($ListFields | Where-Object {$_.Title -ieq 'Status' -and $_.ReadOnlyField -eq $false}).InternalName
            Write-Verbose "User ID Field Internal Name: '$UserIDFieldInternalName'"
            Write-Verbose "Status Field Internal Name: '$StatusFieldInternalName'"
            $ListFieldValues = @{
                $UserIDFieldInternalName = $UserName
                $StatusFieldInternalName = "User Created at $($Now.ToShortDateString()) $($Now.ToShortTimeString()) UTC."
                
            }
            $UpdateSPListItem = Update-SPListItem -SPConnection $SPConnection -ListName $SPListName -ListItemID $ListItemID -ListFieldsValues $ListFieldValues
        }
	} else {
		Write-Error "Error occurred while creating AD Account `"$UserName`". Please manually check the runbook outputs."
	}
}