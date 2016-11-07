    param (
        [object]$WebhookData
    )

    # If runbook was called from Webhook, WebhookData will not be null.
    if ($WebhookData -ne $null) {

        # Collect properties of WebhookData
        $WebhookName    =   $WebhookData.WebhookName
        $WebhookHeaders =   $WebhookData.RequestHeader
        $WebhookBody    =   $WebhookData.RequestBody

        # Collect individual headers. ArgList converted from JSON.
        $From = $WebhookHeaders.From
        $ArgList = ConvertFrom-Json -InputObject $WebhookBody
        Write-Output "Runbook started from webhook $WebhookName by $From."


        # Obtain the WebhookBody containing the AlertContext
        #$WebhookBody = (ConvertFrom-Json -InputObject $WebhookBody)
        $ReqContext = [object]$ArgList.context
        
        # Start each virtual machine
        foreach ($VM in $ArgList)
        {
            $RemoteComputer = $VM.RemoteComputer
            $SqlInstance = $VM.SqlInstance
            $DatabaseName = $VM.DatabaseName

        write-output "WebhookBody value is $ReqContext" 
        #write-output "SQL instance is $ReqContext.SqlInstance"
        #write-output "DB name is $ReqContext.DatabaseName"
        #write-output "DB name is $WebhookBody.RemoteComputer"

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
        }
    }