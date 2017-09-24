#=====================================================================================================
# AUTHOR:          Tao Yang
# Script Name:     WriteToEventLogWA.ps1
# DATE:            20/05/2015
# Version:         1.0
# COMMENT:   - Script in a Write Action module to write structured data into Windows Event log
#=====================================================================================================
Param (
    [Parameter(Mandatory=$true)][string]$EventLog,
    [parameter(Mandatory=$true)][int]$EventID,
    [Parameter(Mandatory=$true)][string]$EventSource,
    [Parameter(Mandatory=$true)][string]$EntryType,
    [Parameter(Mandatory=$true)][string]$Message
)

$ExistingEventSource = Get-Eventlog -LogName $EventLog -Source $EventSource -ErrorAction SilentlyContinue
If (!$ExistingEventSource)
{
    #The event source does not exist, create it now
 New-EventLog -LogName $EventLog -Source $EventSource
}
Write-EventLog -LogName $EventLog -source $EventSource -EventId $EventID -EntryType $EntryType -Message $Message