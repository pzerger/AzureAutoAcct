#Requires -Modules AzureTableEntity
<#
    ===========================================================================================================
    AUTHOR:  Lumagate North America
    DATE:    10/08/2017
    Version: 1.0
    Comment: Security Event Collection solution - Runbook: Copy entites from source table to desintation table
    Requirements:
     - An Azure Automation account to execute this runbook
     - The AzureTableEntity PowerShell PowerShell module must be imported into the Azure Automation account
     - A connection asset with type 'AzureTable' for the source Azure table storage
     - A connection asset with type 'AzureTable' for the destination Azure table storage
     - DO NOT schedule this runbook to run more than once per hour!
    ===========================================================================================================
#>
[CmdletBinding()]
Param (
  [Parameter(Mandatory = $true)][String]$SourceTableConnectionName,
  [Parameter(Mandatory = $true)][String]$DestinationTableConnectionName,
  [Parameter(Mandatory = $true)][String][validateScript({[system.timezoneinfo]::GetSystemTimeZones() | Where-Object Id -ieq $_})]$LocalTimeZoneName,
  [Parameter(Mandatory = $true)][int]$TimeRangeHour
)

#region functions
Function NewSharedKeyLiteAuthorizationHeader
{
  Param (
    [Parameter(Mandatory = $true,HelpMessage = 'Please specify the Azure Storage account name')][ValidateNotNullOrEmpty()][string]$StorageAccountName,
    [Parameter(Mandatory = $true,HelpMessage = 'Please specify an access key for the Azure Storage account')][ValidateNotNullOrEmpty()][String]$StorageAccountAccessKey,
    [Parameter(Mandatory = $true,HelpMessage = 'Please specify the relative URL path of the Azure storage REST API call')][ValidateNotNullOrEmpty()][string]$UrlPath,
    [Parameter(Mandatory = $true,HelpMessage = 'Please specify formatted UTC time stamp in RFC1123 format')][ValidateNotNullOrEmpty()][String]$TimeStamp
  )

  #build authorization string
  Write-Verbose "Start building authorization string"
  [Byte[]]$StorageAccountAccessKeyByteArray = [System.Convert]::FromBase64String($StorageAccountAccessKey)
  $hasher = New-Object System.Security.Cryptography.HMACSHA256
  $hasher.key = $StorageAccountAccessKeyByteArray
  $strToSign = $RFC1123TimeUTC + "`n" + "/" + $StorageAccountName + "/" + $UrlPath

  $AuthKey = [System.Convert]::ToBase64String($hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($strToSign)))
  $SharedKeyLiteAuthorizationHeader = "SharedKeyLite $StorageAccountName`:$AuthKey"
  $SharedKeyLiteAuthorizationHeader
}
Function ProcessBulkInserts
{
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true)][System.Array]$arrEvents,
    [Parameter(Mandatory = $true)][System.Collections.Hashtable]$TableConnection
  )
  $arrBatch = @()
  Foreach ($item in $arrEvents)
  {
    if ($arrBatch.count -lt $Global:BatchLimit)
    {
      $arrBatch += $item
    }
    if ($arrBatch.count -eq $Global:BatchLimit)
    {
      #the maximum batch size reached, inserting now
      Write-output "Inserting $($arrBatch.count) entities in a batch"
      InjectRecords -TableConnection $TableConnection -arrEvents $arrBatch
      $arrBatch = @()
    }
  }
  if ($arrBatch.count -gt 0)
  {
    #Insert the remaining entities
    InjectRecords -TableConnection $TableConnection -arrEvents $arrBatch
  }
}
Function InjectRecords
{
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true)][System.Array]$arrEvents,
    [Parameter(Mandatory = $true)][System.Collections.Hashtable]$TableConnection
  )

  Write-Output -InputObject "Injecting $($arrEvents.count) records to Azure Table"
  #Group events by partition key
  $EventsGroupedByPartitionKey = $arrEvents | Group-Object -Property 'PartitionKey'
  Foreach ($Group in $EventsGroupedByPartitionKey)
  {
    Write-Output -InputObject " - Injecting $($Group.group.count) records to Azure Table - Partition Key: $($Group.name)"
    $AzureTableInjectResult = New-AzureTableEntity -TableConnection $TableConnection -Entities $Group.Group
    If ($AzureTableInjectResult.StatusCode -ge 200 -and $AzureTableInjectResult.StatusCode -le 299 -and $AzureTableInjectResult.RawContent -inotmatch 'http/1.1 400 bad request')
    {
      Write-Output -InputObject "Azure Table log injection successful. HTTP response status code: $($AzureTableInjectResult.StatusCode)"
      Write-Output -InputObject $($AzureTableInjectResult.RawContent)
    }
    else 
    {
      Write-Warning -Message "Azure Table log injection failed. Wait for $InjectionRetryInterval seconds and try again."
      Start-Sleep -Seconds $Global:InjectionRetryInterval
      $AzureTableInjectResult = New-AzureTableEntity -TableConnection $TableConnection -Entities $Group.Group
      If ($AzureTableInjectResult.StatusCode -ge 200 -and $AzureTableInjectResult.StatusCode -le 299 -and $AzureTableInjectResult.RawContent -inotmatch 'http/1.1 400 bad request')
      {
        Write-EventLog -LogName Application -Source $ScheduledJobLoggingSource -EntryType Information -EventId 5 -Message "Azure Table log injection retry successful."
        Write-Output -InputObject "Azure Table log injection retry successful."
      }
      else 
      {
        Write-Error -Message "Azure Table log injection retry failed."
        Write-Output -InputObject $AzureTableInjectResult.RawContent
      }
    }
  }
}
#endregion
#region varaibles
$Global:BatchLimit = 100
$Global:InjectionRetryInterval = 10
$SourceTableConnection = Get-AutomationConnection -Name $SourceTableConnectionName
$DestinationTableConnection = Get-AutomationConnection -Name $DestinationTableConnectionName
#endregion

#region pre-flight checks
#Testing Azure table connection before injection
Write-Output -InputObject '', "Testing Azure Storage connection."

Write-Output -InputObject " - Testing Source Azure Storage connection."
$TestSourceTableConnectionResult = Test-AzureTableConnection -TableConnection $SourceTableConnection
If ($TestSourceTableConnectionResult.Connected -eq $true)
{
  Write-output -InputObject "  - Source Azure table '$($SourceTableConnection.TableName)' connected successfully"
} else {
  If ($TestSourceTableConnectionResult.Status -ne $null)
  {
    Write-Error "Failed to connect to Azure table '$($SourceTableConnection.TableName)': $($TestSourceTableConnectionResult.Status)"
    $LogError = "Failed to connect to Azure table '$($SourceTableConnection.TableName)' in storage account '$($SourceTableConnection.StorageAccount)'. Reason: $($TestSourceTableConnectionResult.Status). REST API error: '$($TestSourceTableConnectionResult.Messages)'."
  } else {
    Write-Error "Failed to connect to Azure table '$($SourceTableConnection.TableName)' with unknown error. Please verify the storage account name and key is correct."
  }
  Exit -1
}

Write-Output -InputObject " - Testing destination Azure Storage connection."
$TestDestionationTableConnectionResult = Test-AzureTableConnection -TableConnection $DestinationTableConnection
If ($TestDestionationTableConnectionResult.Connected -eq $true)
{
  Write-output -InputObject "  - Source Azure table '$($DestinationTableConnection.TableName)' connected successfully"
} else {
  If ($TestDestionationTableConnectionResult.Status -ne $null)
  {
    Write-Error "Failed to connect to Azure table '$($DestinationTableConnection.TableName)': $($TestDestionationTableConnectionResult.Status)"
    $LogError = "Failed to connect to Azure table '$($DestinationTableConnection.TableName)' in storage account '$($DestinationTableConnection.StorageAccount)'. Reason: $($TestDestionationTableConnectionResult.Status). REST API error: '$($TestDestionationTableConnectionResult.Messages)'."
  } else {
    Write-Error "Failed to connect to Azure table '$($DestinationTableConnection.TableName)' with unknown error. Please verify the storage account name and key is correct."
  }
  Exit -1
}
#endregion

#region construct source table search string
$UTCNow = (Get-Date).ToUniversalTime()
$UTCYear = $UTCNow.Year
$UTCMonth = $UTCNow.Month
$UTCDay = $UTCNow.Day
$UTCHour = $UTCNow.Hour

$UTCHourBegining = Get-Date -Year $UTCYear -Month $UTCMonth -Day $UTCDay -Hour $UTCHour -Minute 0 -Second 0 -Millisecond 0
$UTCEarliestHourToKeep = $UTCHourBegining.AddHours(-$TimeRangeHour)
$UTCEarliestHourToKeep = [Datetime]::SpecifyKind($UTCEarliestHourToKeep, [DateTimeKind]::Utc)
#Time zone ID
$LocalTimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById($LocalTimeZoneName)

#Convert UTC time to local time (based on the time zone from input parameter)
$LocalEarliestHourToKeep = [System.TimeZoneInfo]::ConvertTimeFromUtc($UTCEarliestHourToKeep, $LocalTimeZone)

#Azure table search string
$SearchString = "TimeCreated ge datetime'$($LocalEarliestHourToKeep.tostring('yyyy-MM-ddThh:mm:ss.000Z'))'"
Write-Output '', "Source Table search query: `"$SearchString`""
#Get entities from the source table and inject to destination table
Write-output '', "Start retrieving events from source Azure table."
#for perfomrance enhancement, not using AzureTableEntity module to query source table

$SourceStorageAccountName = $SourceTableConnection.StorageAccount
$SourceTableName = $SourceTableConnection.TableName
$SourceStorageAccountAccessKey = $SourceTableConnection.StorageAccountAccessKey

$SourceTableStorageBaseUri = "https://$SourceStorageAccountName.table.core.windows.net/$SourceTableName"
$RFC1123TimeUTC  = [datetime]::UtcNow.ToString("R")

#build authorization string
$SourceAuthorizationHeaderValue = NewSharedKeyLiteAuthorizationHeader -StorageAccountName $SourceStorageAccountName -StorageAccountAccessKey $SourceStorageAccountAccessKey -UrlPath $SourceTableName -TimeStamp $RFC1123TimeUTC
$RequestHeaders = @{
  'x-ms-version' = '2015-12-11'
  'x-ms-date' = $RFC1123TimeUTC
  'Authorization' = $SourceAuthorizationHeaderValue
  'Accept' = 'application/json;odata=nometadata'
  'Accept-Charset' = 'UTF-8'
  'DataServiceVersion' = '1.0;NetFx'
  'MaxDataServiceVersion' = '3.0;NetFx'
}
$SourceTableStorageSearchUri = "$SourceTableStorageBaseUri`?`$filter=$SearchString"
Write-Output "Source Table Storage search Uri: '$SourceTableStorageSearchUri'"
$iQueryBatch = 1
$iTotalEntity = 0
$SearchRequest = Invoke-WebRequest -UseBasicParsing -Uri $SourceTableStorageSearchUri -Method Get -ContentType "application/json" -Headers $RequestHeaders
$ReturnedEntities = ($SearchRequest.Content | ConvertFrom-JSON).value
$iTotalEntity = $iTotalEntity + $ReturnedEntities.count
<#
#Convert Datetime fields from string back to datetime type
foreach ($item in $ReturnedEntities)
{
  #remove odata.etag
  $item.psobject.Properties.Remove('odata.etag')
  #Convert the built-in timestamp field
  $item.Timestamp = [datetime]::Parse($item.Timestamp)
  #Convert TimeCreated field
  $item.TimeCreated = [datetime]::Parse($item.TimeCreated)
}
#>
Write-Output "  - Source table query batch $iQueryBatch`: Number of entities retrieved: $($ReturnedEntities.count)"
If ($ReturnedEntities.count -gt 0)
{
  Write-output '', '   - Preparing table entities for destination table insertion'
  Write-output '    - Removing built-in Timestamp property from source table search results'
  Foreach ($item in $ReturnedEntities)
  {
    $item.psobject.properties.remove('Timestamp')
  }

  Write-output "   - Start inserting events to destination Azure table."
  $InsertToDestination = ProcessBulkInserts -TableConnection $DestinationTableConnection -arrEvents $ReturnedEntities -Verbose
} else {
  Write-Output '', "  - No entities found from sources table storage. Nothing to insert."
}

Do
{
  If ($SearchRequest.Headers.ContainsKey("x-ms-continuation-NextRowKey") -or $SearchRequest.Headers.ContainsKey("x-ms-continuation-NextPartitionKey"))
  {
    #Continue searching
    $iQueryBatch ++
    Write-Output " - Query did not return all entities. Continue Querying."
    $SubsequentTableStorageSearchUri ="$SourceTableStorageSearchUri`&NextPartitionKey=$($SearchRequest.Headers."x-ms-continuation-NextPartitionKey")&NextRowKey=$($SearchRequest.Headers."x-ms-continuation-NextRowKey")"
    Write-Verbose "Starting a subsequent query: '$SubsequentTableStorageSearchUri'"
    $SearchRequest = Invoke-WebRequest -UseBasicParsing -Uri $SubsequentTableStorageSearchUri -Method Get -ContentType "application/json" -Headers $RequestHeaders
    $ReturnedEntities = ($SearchRequest.Content | ConvertFrom-JSON).value
    If ($SearchRequest.Headers.ContainsKey("x-ms-continuation-NextRowKey") -or $SearchRequest.Headers.ContainsKey("x-ms-continuation-NextPartitionKey"))
    {
      $finished = $false
    } else {
      $finished = $true
    }

    Write-Output "  - Source table query batch $iQueryBatch`: Number of entities retrieved: $($ReturnedEntities.count)"
    If ($ReturnedEntities.count -gt 0)
    {
      $iTotalEntity = $iTotalEntity + $ReturnedEntities.count
      Write-output '   - Preparing table entities for destination table insertion'
      Write-output '    - Removing built-in Timestamp property from source table search results'
      Foreach ($item in $ReturnedEntities)
      {
        $item.psobject.properties.remove('Timestamp')
      }

      Write-output "   - Start inserting events to destination Azure table."
      $InsertToDestination = ProcessBulkInserts -TableConnection $DestinationTableConnection -arrEvents $ReturnedEntities
    } else {
      Write-Output '', "  - No entities found from sources table storage. Nothing to insert."
    }

  } else {
    $finished = $true
  }
} Until ($finished -eq $true)
Write-output "All entities processed. Total number of entities: $iTotalEntity"
  
#$SourceSearchResult = Get-AzureTableEntity -TableConnection $SourceTableConnection -QueryString $SearchString -GetAll $true -Verbose

Write-Output "Done!"