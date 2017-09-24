workflow Parse-AzureRmVMPowerState
{
    Param(
    [Parameter(Mandatory=$true)][String]$VMStatusJSON
    )
    Write-Verbose "VM Status in JSON: '$VMStatusJSON'"
    #Convert From JSON
    $arrStatuses = ConvertFrom-Json -InputObject $VMStatusJSON
    $objPowerState = $arrStatuses | Where-Object {$_.Code -match '^PowerState\/'}
    $VMPowerState = $objPowerState.Code.split("/")[1]
    Write-Verbose "Provisioning State: '$VMPowerState'"
    $VMPowerState
}