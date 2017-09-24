workflow Process_OMSSavedSearchArray
{
	$QueriesToProcess = Get-AutomationVariable -Name 'MMSDemo_OMS_SavedSearchRemediation_Array'
    $QueryArray = $QueriesToProcess.Split(",")
	

    ForEach($SavedSearchName in $QueryArray)
    {
        Get-OMSSavedSearchResult_Lee -OMSConnectionName "OMS_Demo" -SavedSearchName $SavedSearchName -EmailAddress 'lberg@concurrency.com'
	}


}