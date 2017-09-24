workflow MMS_MonitorLogDemo
{
	$OMSConnectionName = "OMS_Demo"
    $EmailAddress = "leealanberg@gmail.com"

    #Retrieve OMS connection details
    Write-Verbose "Retrieving OMS connection details from connection object '$OMSConnectionName'."
    $OMSConnection = Get-AutomationConnection -Name $OMSConnectionName
    $Token = Get-AADToken -OMSConnection $OMSConnection
    $SubscriptionID = $OMSConnection.SubscriptionID
    $ResourceGroupName = $OMSConnection.ResourceGroupName
    $WorkSpaceName = $OMSConnection.WorkSpaceName

    #region Variables
    $SMTPConnection = Get-AutomationConnection SMTPNotification
  
    $QueriesToProcess = "Alerts Warnings in the Last Hour,Runbook Executions for Last 24 Hours,New Software Installed on Servers"
        
    $QueryArray = $QueriesToProcess.Split(",")

	$SearchQuery = 'Type=Event Computer="ORCH01.contoso.corp" Source="MMSDemo1" TimeGenerated>NOW-1HOUR'
	$SearchQuery = 'Type=Event Computer="ORCH01.contoso.corp" Source="MMSDemo1"'
		
			
	Write-Output "Starting Invoke-OMSSearchQuery function"

    $SearchResult = Invoke-OMSSearchQuery -SubscriptionID $SubscriptionID -ResourceGroupName $ResourceGroupName -OMSWorkspaceName $WorkSpaceName -Query $SearchQuery -Token $Token
    
	Write-Output $SearchResult
	
	Write-Output "Starting Inlinescript for processing"
	
	$out = InlineScript{
		
		$SearchResultString = $USING:SearchResult
		$Result = "NotEvaluated"
		
		IF($SearchResultString.Contains("TimeGenerated"))
		{
			$Result = "ResultsFound"
		}
		ELSE
		{
			$Result = "NoResults"
		}
			
		$Result	
		
	}
	
	Write-Output $out
	
	IF($out -eq 'ResultsFound' )
	{
		Write-Output "My Special App Error Found!!! - Starting Reset IIS Runbook!!"
			
		InlineScript{
			
			Import-Module AzureRM.Automation
		# Authenticate with Azure AD credentials
		$cred = Get-AutomationPSCredential -Name 'DefaultAzureCredential'
		Add-AzureAccount -Credential $cred
		
		Login-AzureRmAccount -Credential $cred
					
		Start-AzureRMAutomationRunbook –AutomationAccountName "contoso-testrba" –Name "MMS_RestartIIS_Service" -RunOn "ConfigMgrPool"	-ResourceGroupName "Default-Networking"
				
			
		}
		
		Write-Output "Restart IIS Runbook Completed!"
	}
	
	Write-Output "Runbook Complete"
	
	
}