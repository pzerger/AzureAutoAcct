workflow MMS_RestartIIS_Service
{
	

	InlineScript{ 
		#MMS_RestartIIS_Service
		
		New-EventLog -Logname System -Source OMSAutomation
	
		Write-EventLog -EventId 1 -LogName System -Message "Runbook Restart IIS Service Started!" -Source OMSAutomation
		
		net start WinRM
		
		$Cred = Get-AutomationPSCredential -Name 'SCCMCred'
	
		Write-EventLog -EventId 1 -LogName System -Message "Creating Session!" -Source OMSAutomation

		$Session = New-PSSession -computername "10.1.1.31" -credential $Cred
		
		Write-EventLog -EventId 1 -LogName System -Message "Created Session - Now Invoking Command!" -Source OMSAutomation
		
		Invoke-Command -session $Session -scriptblock {IISRESET.EXE}
		
		Write-EventLog -EventId 1 -LogName System -Message "Session Command Complete - Closing SEssion...!" -Source OMSAutomation
		
		Remove-PSSession $Session
		
		Write-EventLog -EventId 1 -LogName System -Message "Runbook Restart IIS Service Completed!" -Source OMSAutomation
			
	}
}