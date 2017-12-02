function Get-IISSiteBackConnectionHelper {
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

        $allHostnameEntries = @(Get-TecBoxBackConnectionHostNames) | ForEach-Object {
            [PsCustomObject] @{ Hostname = $_ }
        }
    }
    
    process {
        try {
            if (![string]::IsNullOrWhiteSpace($Name)) {
                $Name = $Name.Trim()
            }
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

            foreach ($site in $selectedSites) {

                $siteEntries = $site.Bindings | Select-Object -Exp Host -Unique |
                    Select-object @{n = 'Hostname'; e = { $_ }}, @{n = 'SiteName'; e = { $site.Name }}

                $siteEntries | ForEach-Object {
                    $siteEntry = $_
                    $allHostnameEntries | Where-Object { $_.Hostname -eq $siteEntry.Hostname } |
                        Select-Object -Property *, @{ n = 'SiteName'; e = { $siteEntry.SiteName } }
                }
            }

        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}