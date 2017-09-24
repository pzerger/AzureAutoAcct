Param(
  [object]$WebhookData
)

Write-Output $Message

        $WebhookName    =   $WebhookData.WebhookName
        $WebhookBody    =   $WebhookData.RequestBody
        $WebhookHeaders =   $WebhookData.RequestHeader

        $WebhookBody = (ConvertFrom-Json -InputObject $WebhookBody)

        $Message = $WebhookBody.Message

        # Collect individual headers. VMList converted from JSON.
        $From = $WebhookHeaders.From
        Write-Output "Runbook started from webhook $WebhookName by $From."
        Write-Output "Message is: $Message"
