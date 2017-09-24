workflow Parse-AzureRmVMProvisioningState
{
    Param(
    [Parameter(Mandatory=$true)][String]$VMStatusJSON
    )
    Write-Verbose "VM Status in JSON: '$VMStatusJSON'"
    #Convert From JSON
    $arrStatuses = ConvertFrom-Json -InputObject $VMStatusJSON
    $objProvisioningState = $arrStatuses | Where-Object {$_.Code -match '^ProvisioningState\/'}
    $VMProvisioningState = $objProvisioningState.Code.split("/")[1]
    Write-Verbose "Provisioning State: '$VMProvisioningState'"
    $VMProvisioningState
}