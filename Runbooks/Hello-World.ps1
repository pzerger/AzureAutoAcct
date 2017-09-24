Param(
  [Parameter(Mandatory=$true)][string]$Message
)


New-EventLog -Logname System -Source OMSAutomation

Write-EventLog -EventId 1 -LogName System -Message "HELLO WORLD!" -Source OMSAutomation

$file = "c:\Runbooks\HelloWorld.txt"

$Message | Add-Content -Path $file

$file = "c:\Runbooks\GetProcess.txt"

Get-Process | Add-Content -Path $file


Write-EventLog -EventId 1 -LogName System -Message "HELLO WORLD is done!" -Source OMSAutomation

		# Log an event 
		New-HybridWorkerRunbookLogEntry -Log System -Id 890 -Level 'Error' -Source 'AzureAutomation Job Process' `
		-Message "This is an error test message logged from hybrid worker within a runbook."