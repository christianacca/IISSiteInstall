function Get-IISSiteHostsFileEntry {
    <#
    .SYNOPSIS
    Gets the list of host names that are assigned to IIS Site bindings that also appear 
    in the Windows hosts file
    
    .DESCRIPTION
    The hosts file (C:\Windows\System32\drivers\etc\hosts) is used to map hostnames to 
    IP addresses instead of using a DNS server to provide that resolution.

    This function returns those host names in the hosts file that are assigned to IIS Site 
    bindings.

    Items in the output have a 'IsShared' property. A hostname is considered shared if it
    assigned to bindings on more than one Website.

    This 'IsShared' property will typically be used to determine which host names can
    be safely removed from the hosts file when an IIS Website is removed
    
    .PARAMETER Name
    The name of the IIS Website to filter results
    
    .PARAMETER InputObject
    The instance the IIS Website to filter results
    
    .EXAMPLE
    Get-CaccaIISSiteHostsFileEntry Series5

	IpAddress Hostname      SiteName IsShared
	--------- --------      -------- --------
	127.0.0.1 local-series5 Series5     False
    

    #>
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param (
        [Parameter(ValueFromPipeline, ParameterSetName = 'Name', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(ValueFromPipeline, ParameterSetName = 'Object', Position = 0)]
        [Microsoft.Web.Administration.Site] $InputObject
        
    )
    
    begin {
        Set-StrictMode -Version 'Latest'
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        $allEntries = @()
        $allEntries += Get-IISSiteHostsFileEntryHelper
    }
    
    process {
        try {

            $selectedSites = @()
            $selectedSites += if ($InputObject) {
                $InputObject
            }
            elseif (![string]::IsNullOrWhiteSpace($Name)) {
                Get-IISSite $Name
            }
            else {
                Get-IISSite
            }

            $siteEntries = @($selectedSites | Get-IISSiteHostsFileEntryHelper)

            $siteEntries | ForEach-Object {
                $entry = $_
                $isShared = ($allEntries | 
                        Where-Object Hostname -eq $entry.Hostname | 
                        Select-Object SiteName -Unique | Measure-Object).Count -gt 1
                $entry | Select-Object -Property *, @{ n='IsShared'; e={ $isShared }}
            }

        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}