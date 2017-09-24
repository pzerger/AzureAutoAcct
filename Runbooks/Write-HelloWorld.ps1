workflow Write-HelloWorld { 
    param ( 
         
        # Optional parameter of type string.  
        # If you do not enter anything, the default value of Name  
        # will be World 
        [parameter(Mandatory=$false)] 
        [String]$Name = "World" 
    ) 
         
        Write-Output "Hello $Name" 
		
		# Log an event 
  # New-HybridWorkerRunbookLogEntry -LogName System -Id 999 -Level 'Error' -Source 'AzureAutomation Job Process' `
  # -Message "This is an error test message logged from hybrid worker within a runbook."
	
}