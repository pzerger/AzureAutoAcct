Param(
[Parameter(Mandatory=$true)][string]$GroupDisplayName,
[Parameter(Mandatory=$true)][Int32]$DurationInMin,
[Parameter(Mandatory=$true)][string]$Comment
)

#region variables
$OpsMgrSDKConnectionName = "OpsMgr_Contoso"
$MaintModeReason = "PlannedOther"
#endregion
Write-Verbose "Getting OpsMgr SDK connection object."
$OpsMgrSDKConn = Get-AutomationConnection -Name $OpsMgrSDKConnectionName
Write-Verbose "Management Server: '$($OpsMgrSDKConn.ComputerName)'."

Import-Module -Name 'C:\Windows\System32\WindowsPowerShell\v1.0\Modules\OpsMgrExtended'
#Connect to MG
Write-Verbose "Connecting to OpsMgr Management Group via SDK."
$MG = Connect-OMManagementGroup -SDKConnection $OpsMgrSDKConn
Write-Verbose "Connected to management group '$($MG.Name)'."

Write-Verbose "looking up group '$GroupDisplayName'."
$GroupClassCriteria = New-Object Microsoft.EnterpriseManagement.Configuration.MonitoringClassCriteria("DisplayName='$GroupDisplayName'")
$GroupClasses = $MG.GetMonitoringClasses($GroupClassCriteria)
Foreach ($GroupClass in $GroupClasses)
{
    $Group = $MG.GetMonitoringObjects($GroupClass)[0]
    If (!($Group.InMaintenanceMode))
    {
        Write-Output "Putting group '$($Group.DisplayName)' into maintenance mode for $DurationInMin minutes."
        $MaintModeStart = (Get-Date).ToUniversalTime()
        $MaintModeEnd = $MaintModeStart.AddMinutes($DurationInMin)
        $Group.ScheduleMaintenanceMode($MaintModeStart, $MaintModeEnd, [Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason]::$MaintModeReason, $Comment, [Microsoft.EnterpriseManagement.Common.TraversalDepth]::Recursive)
    }
}
Write-Output "Done."