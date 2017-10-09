#Requires -Modules AzureTableEntity
<#
    ===========================================================================
    AUTHOR:  Lumagate North America
    DATE:    09/13/2017
    Version: 1.0
    Comment: Security Event Collection solution - Azure table grooming script
    ===========================================================================
#>
[CmdletBinding()]
Param (
  [Parameter(Mandatory = $true)][String]$TableConnectionName,
  [Parameter(Mandatory = $true)][int]$RetentionHour
)

#region functions
Function GetSearchString
{
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][int]$RetentionHour
  )
  $UTCNow = (Get-Date).ToUniversalTime()
  $UTCYear = $UTCNow.Year
  $UTCMonth = $UTCNow.Month
  $UTCDay = $UTCNow.Day
  $UTCHour = $UTCNow.Hour

  $UTCHourBegining = Get-Date -Year $UTCYear -Month $UTCMonth -Day $UTCDay -Hour $UTCHour -Minute 0 -Second 0 -Millisecond 0
  $UTCEarliestHourToKeep = $UTCHourBegining.AddHours(-$RetentionHour)
  $UTCEarliestHourToKeep = [Datetime]::SpecifyKind($UTCEarliestHourToKeep, [DateTimeKind]::Utc)

  $SearchString = "TimeCreated lt datetime'$($UTCEarliestHourToKeep.tostring('yyyy-MM-ddTHH:mm:ss.000Z'))'"
  $SearchString
}

Function DeleteEvents
{
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true)][System.Array]$arrEvents,
    [Parameter(Mandatory = $true)][System.Collections.Hashtable]$TableConnection
  )
  $DeletionRetryInterval = 10
  Write-Output -InputObject "Deleting $($arrEvents.count) records to Azure Table"
  #Group events by partition key
  $EventsGroupedByPartitionKey = $arrEvents | Group-Object -Property 'PartitionKey'
  Foreach ($Group in $EventsGroupedByPartitionKey)
  {
    Write-Output -InputObject " - Deleting $($Group.group.count) records to Azure Table - Partition Key: $($Group.name)"
    $AzureTableDeleteResult = Remove-AzureTableEntity -TableConnection $TableConnection -Entities $Group.Group
    If ($AzureTableDeleteResult.StatusCode -ge 200 -and $AzureTableDeleteResult.StatusCode -le 299 -and $AzureTableDeleteResult.RawContent -inotmatch 'http/1.1 400 bad request')
    {
      Write-Output -InputObject "Azure Table log deletion successful. HTTP response status code: $($AzureTableDeleteResult.StatusCode)"
    }
    else 
    {
      Write-Warning -Message "Azure Table log deletion failed. Wait for $DeletionRetryInterval seconds and try again."
      Start-Sleep -Seconds $DeletionRetryInterval
      $AzureTableDeleteResult = New-AzureTableEntity -TableConnection $TableConnection -Entities $Group.Group
      If ($AzureTableDeleteResult.StatusCode -ge 200 -and $AzureTableDeleteResult.StatusCode -le 299 -and $AzureTableDeleteResult.RawContent -inotmatch 'http/1.1 400 bad request')
      {
        Write-Output -InputObject "Azure Table log deletion retry successful."
      }
      else 
      {
        Throw "Azure Table log deletion retry failed for '$($EventLog.LogName)' log."
        Write-Output -InputObject $AzureTableDeleteResult.RawContent
        Exit -1
      }
    }
  }
}
#endregion

#Variables
$Global:BatchLimit = 100
$TableConnection = Get-AutomationConnection -Name $TableConnectionName

If (!$TableConnection)
{
  Throw "Unable to get connection details for the Azure table"
  Exit -1
}

#Testing Azure table connection before injection
Write-Output -InputObject '', "Testing Azure Storage connection."
$TestTableConnectionResult = Test-AzureTableConnection -TableConnection $TableConnection
If ($TestTableConnectionResult.Connected -eq $true)
{
  Write-output -InputObject "  -Azure table '$($TableConnection.TableName)' connected successfully"
} else {
  If ($TestTableConnectionResult.Status -ne $null)
  {
    Write-Error "Failed to connect to Azure table '$($TableConnection.TableName)': $($TestTableConnectionResult.Status)"
    $LogError = "Failed to connect to Azure table '$($TableConnection.TableName)' in storage account '$($TableConnection.StorageAccount)'. Reason: $($TestTableConnectionResult.Status). REST API error: '$($TestTableConnectionResult.Messages)'."
  } else {
    Write-Error "Failed to connect to Azure table '$($TableConnection.TableName)' with unknown error. Please verify the storage account name and key is correct."
  }
  Exit -1
}

#Delete entities that have passed retention period
Write-Output "Deleting Azure table entities that have passed retention peroid"
$AllDeleted = $false
$SearchString = GetSearchString -RetentionHour $RetentionHour
Write-Output " - Old entities search string: `"$SearchString`""
$i = 0
Do
{
  Write-Output " - Searching old entities..."
  
  $EntitiesToBeDeleted = Get-AzureTableEntity -TableConnection $TableConnection -QueryString $SearchString
  Write-output "  - $($EntitiesToBeDeleted.Count) entities found."
  If ($EntitiesToBeDeleted.count -eq 0)
  {
    $AllDeleted = $true
  } else {
    $arrBatchDelete = @()
    foreach ($item in $EntitiesToBeDeleted)
    {
      $i++
      If ($arrBatchDelete.Count -lt $BatchLimit)
      {
        $arrBatchDelete +=$item
      }
      
      If ($arrBatchDelete.Count -eq $BatchLimit)
      {
        #Perform bulk delete
        DeleteEvents -arrEvents $arrBatchDelete -TableConnection $TableConnection
      
        #clear array and reset batch count
        $arrBatchDelete = @()
      }
    }

    #Remove the remaining
    if ($arrBatchDelete.count -gt 0)
    {
      #Delete from Azure Table
      DeleteEvents -arrEvents $arrBatchDelete -TableConnection $TableConnection

      #clear array and reset batch count
      $arrBatchDelete = @()
    }
  }

} While ($AllDeleted -eq $false)
Write-Output '' "Total number of deleted events: $i"
Write-output '', 'Done!'
