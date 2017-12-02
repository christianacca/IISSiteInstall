function GetAppPoolOtherSiteCount
{
    [CmdletBinding()]
    param (
        [string] $ExcludeSiteName,
        [string] $AppPoolName
    )
    
    begin
    {
        Set-StrictMode -Version 'Latest'
        $ErrorActionPreference = 'Stop'
    }
    
    process
    {
        Get-IISSiteHierarchyInfo | 
            Where-Object { $_.AppPool_Name -eq $AppPoolName -and $_.Site_Name -ne $ExcludeSiteName } |
            Select-Object Site_Name -Unique |
            Measure-Object | Select-Object -Exp Count
    }
}