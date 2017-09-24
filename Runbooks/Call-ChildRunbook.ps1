.\Write-WindowsEvent.ps1 `
		-Message 'Test message' `
		-EntryType 'Information' `
		-EventLog 'System' `
		-EventSource OMSAutomation `
		-EventID 50001