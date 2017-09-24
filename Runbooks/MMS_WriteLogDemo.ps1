net start WinRM

Set-Item WSMan:\localhost\Client\TrustedHosts -Value 10.1.1.31 -Force

$Cred = Get-AutomationPSCredential -Name 'SCCMCred'

Invoke-Command -Computer "10.1.1.31" -ScriptBlock {New-EventLog -Logname Application -Source MMSDemo1} -Credential $Cred
Invoke-Command -Computer "10.1.1.31" -ScriptBlock {Write-EventLog -EventId 23 -entrytype Warning -LogName Application -Message 'Application is trying todo something' -Source MMSDemo1} -Credential $Cred
Invoke-Command -Computer "10.1.1.31" -ScriptBlock {Write-EventLog -EventId 24 -entrytype Warning -LogName Application -Message 'Application is still trying to do something!' -Source MMSDemo1} -Credential $Cred
Invoke-Command -Computer "10.1.1.31" -ScriptBlock {Write-EventLog -EventId 25 -entrytype Error -LogName Application -Message 'Application has not done something Serious Problem' -Source MMSDemo1} -Credential $Cred
