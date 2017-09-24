param(
    [parameter(Mandatory=$true, HelpMessage="Site server where the SMS Provider is installed")]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({Test-Connection -ComputerName $_ -Count 1 -Quiet})][string]$SiteServer,
    [parameter(Mandatory=$true)][string]$DeviceName,
	[parameter(Mandatory=$true)][string]$MACAddress,
    [parameter(Mandatory=$false)][string]$CollectionName
)
# Get credential
$Credential = Get-AutomationPSCredential -Name 'SCCMCred'

# Determine SiteCode from WMI on remote Site server
$SiteCodeScriptBlock = {
        param($SiteServer)
    $SiteCodeObjects = Get-WmiObject -Namespace "root\SMS" -Class SMS_ProviderLocation -ComputerName $SiteServer -ErrorAction Stop
    foreach ($SiteCodeObject in $SiteCodeObjects) {
        if ($SiteCodeObject.ProviderForLocalSite -eq $true) {
                        [PSCustomObject]@{
                SiteCode = $SiteCodeObject.SiteCode
                        }
        }
    }
}
$SiteCodeCommand = Invoke-Command -ComputerName $SiteServer -ScriptBlock $SiteCodeScriptBlock -Credential $Credential -ArgumentList $SiteServer
$SiteCode = $SiteCodeCommand.SiteCode

# Import device
$ImportScriptBlock = {
        param($SiteServer, $SiteCode, $DeviceName, $MACAddress)
        $WMIConnection = ([WMIClass]"\\$($SiteServer)\root\SMS\site_$($SiteCode):SMS_Site")
    $NewEntry = $WMIConnection.psbase.GetMethodParameters("ImportMachineEntry")
    $NewEntry.MACAddress = $MACAddress
    $NewEntry.NetbiosName = $DeviceName
    $NewEntry.OverwriteExistingRecord = $true
    $WMIConnection.psbase.InvokeMethod("ImportMachineEntry", $NewEntry, $null)
}
Invoke-Command -ComputerName $SiteServer -ScriptBlock $ImportScriptBlock -Credential $Credential -ArgumentList @($SiteServer, $SiteCode, $DeviceName, $MACAddress)