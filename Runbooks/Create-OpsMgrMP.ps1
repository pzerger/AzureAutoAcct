workflow Create-OpsMgrMP
{
	Param(
    [Parameter(Mandatory=$true)][String]$Name,
    [Parameter(Mandatory=$true)][String]$DisplayName,
    [Parameter(Mandatory=$false)][String]$Description,
    [Parameter(Mandatory=$true)][String]$Version
    )
    
	Import-Module -Name 'C:\Windows\System32\WindowsPowerShell\v1.0\Modules\OpsMgrExtended'
	
	#SharePoint list name
	#$SharePointListName = "New SCOM MPs"

    #Get OpsMgr SDK connection object
    Write-Verbose "Getting OpsMgr SDK connection object"
    $OpsMgrSDKConn = Get-AutomationConnection -Name "OpsMgr_Contoso"
	Write-Verbose "Management Server: '$OpsMgrSDKConn.ComputerName'."
	#Get SharePointSDK connection object
	#$SPConn = Get-AutomationConnection "RequestsSPSite"

    #Create MP
    Write-Verbose "Creating MP '$Name'."
    $MPCreated = InlineScript
    {
        #Import the OpsMgrExtended module
        Write-Verbose "PSModulePath: '$env:PsModulePath'"
        
        #Import-Module OpsMgrExtended
        #Validate MP Name
        If ($USING:Name -notmatch "([a-zA-Z0-9]+\.)+[a-zA-Z0-9]+")
        {
            #Invalid MP name entered
            $ErrMsg = "Invalid Management Pack name specified. Please make sure it only contains alphanumeric charaters and only use '.' to separate words. i.e. Your.Company.Test1.MP."
            Write-Error $ErrMsg 
        } else {
            #Name is valid, creating the MP
            New-OMManagementPack -SDKConnection $USING:OpsMgrSDKConn -Name $USING:Name -DisplayName $USING:DisplayName -Description $USING:Description -Version $USING:Version
        }
        Return $MPCreated
    }

    If ($MPCreated)
	{
		Write-Output "Management Pack `"$Name`" created."
	} else {
		Write-Error "Unable to create Management Pack `"$Name`"."
	}

	Write-Output "Done."
}