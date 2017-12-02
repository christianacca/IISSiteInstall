function Get-IISSiteBackConnection {
    <#
    .SYNOPSIS
    Gets the list of host names that are assigned to IIS Site bindings that also appear 
    in the BackConnectionHostNames registry value
    
    .DESCRIPTION
    The BackConnectionHostNames registry value is used to bypass the loopback
    security check for specific host names.

    This function returns those host names in the BackConnectionHostNames registry value 
    that are assigned to IIS Site bindings.

    Items in the output have a 'IsShared' property. A hostname is considered shared if it
    assigned to bindings on more than one Website.

    This 'IsShared' property will typically be used to determine which host names can
    be safely removed from the BackConnectionHostNames list when an IIS Website is removed
    
    .PARAMETER Name
    The name of the IIS Website to filter results
    
    .PARAMETER InputObject
    The instance the IIS Website to filter results
    
    .EXAMPLE
    Get-CaccaIISSiteBackConnection Series5

    Hostname      SiteName IsShared
	--------      -------- --------
	local-series5 Series5     False
    
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
        $allEntries += Get-IISSiteBackConnectionHelper
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

            $siteEntries = @($selectedSites | Get-IISSiteBackConnectionHelper)

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