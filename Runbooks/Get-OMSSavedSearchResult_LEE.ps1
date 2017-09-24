workflow Get-OMSSavedSearchResult_LEE
{
   Param(
    [Parameter(Mandatory=$true)][String]$OMSConnectionName,
    [Parameter(Mandatory=$true)][String]$SavedSearchName,
    [Parameter(Mandatory=$true)][String]$EmailAddress
    )

    #region Variables
    $SMTPConnection = Get-AutomationConnection SMTPNotification
    $EmailSubject = "OMS Saved Search Result for '$SavedSearchName'"
    #endregion

    #Retrieve OMS connection details
    Write-Verbose "Retrieving OMS connection details from connection object '$OMSConnectionName'."
    $OMSConnection = Get-AutomationConnection -Name $OMSConnectionName
    $Token = Get-AADToken -OMSConnection $OMSConnection
    $SubscriptionID = $OMSConnection.SubscriptionID
    $ResourceGroupName = $OMSConnection.ResourceGroupName
    $WorkSpaceName = $OMSConnection.WorkSpaceName

    Write-Verbose "Execting saved search query `"$SavedSearchName`"."
    $TimeStampUTC = (Get-Date).ToUniversalTime()
    $SearchResult = Invoke-OMSSavedSearch -SubscriptionID $SubscriptionID -ResourceGroupName $ResourceGroupName -OMSWorkspaceName $WorkSpaceName -queryName $SavedSearchName -Token $Token

    #Export search result to CSV
	$CSVNAME = $SavedSearchName + "_Result.csv"
	
    $ExportCSVPath = Join-path $env:temp $CSVNAME
    if (Test-path $ExportCSVPath)
    {
        Write-Verbose "Removing the previous export CSV file '$ExportCSVPath'."
        Remove-Item -Path $ExportCSVPath -Force
    }
    Write-Verbose "Exporting the search result to '$ExportCSVPath'."
    $ExportCSVResult = inlinescript {
        $arrSearchResult = New-Object System.Collections.ArrayList
        Foreach ($item in $USING:SearchResult)
        {
            [void]$arrSearchResult.Add((New-Object PSObject -Property $item))
        }
        $arrSearchResult | Export-Csv -Path $USING:ExportCSVPath -NoTypeInformation
    }

    #Email out the result
    $Body = @"
Hello,

this is a system generated message. The OMS Search Result for saved search '$SavedSearchName' at $TimeStampUTC (UTC) is attached.

Best Regards,
Azure Automation
"@

Write-Verbose "Sending search result to '$EmailAddress'."
Send-Email `
	-Body $Body `
	-HTMLBody $false `
	-SMTPSettings $SMTPConnection `
	-Subject $EmailSubject `
	-To $EmailAddress `
    -Attachments $ExportCSVPath
Write-Output "Done."	
	
}