PARAM(

$RemoteComputer,
$SqlInstance,
$DatabaseName

)

$strScriptUser = Get-AutomationVariable -Name 'ContosoAdminUser'
$strPass = Get-AutomationVariable -Name 'ContosoAdminPassword'
$PSS = ConvertTo-SecureString $strPass -AsPlainText -Force
$cred = new-object system.management.automation.PSCredential $strScriptUser,$PSS

$ScriptBlock = 

Invoke-Command -Computername $RemoteComputer -Credential $cred -ScriptBlock {

#Import SQL Server Module called SQLPS
Import-Module SQLPS -DisableNameChecking
 
#Your SQL Server Instance Name
$SqlInst = "$using:SqlInstance"
$Srvr = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $SqlInst
 
#database PSDB with default settings
#by assuming that this database does not yet exist in current instance
$DBName = "$using:DatabaseName"
$db = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Database($Srvr, $DBName)
$db.Create()

    }