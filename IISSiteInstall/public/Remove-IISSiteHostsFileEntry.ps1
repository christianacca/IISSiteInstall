#Requires -RunAsAdministrator

function Remove-IISSiteHostsFileEntry {
    <#
    .SYNOPSIS
    Removes the host name(s) from the hosts file
    
    .DESCRIPTION
    Removes the host name(s) from the hosts file
    
    .PARAMETER InputObject
    The host name entry to remove
    
    .PARAMETER Force
    Remove even if the host name is assigned to more than one site
    
    .EXAMPLE
    Get-CaccaIISSiteHostsFileEntry MySite | Remove-CaccaIISSiteHostsFileEntry
    
    .NOTES
    Exception thrown when:
    * the host name is assigned to more than one site and -Force is NOT supplied
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [PsCustomObject[]] $InputObject,

        [switch] $Force
        
    )
    
    begin {
        Set-StrictMode -Version 'Latest'
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'
    }
    
    process {
        try {

            $shared = $InputObject | Where-Object IsShared
            if ($shared -and !$Force) {
                throw "Cannot remove hostname(s) - one or more entries are shared by multiple sites"
            }

            $hostName = $InputObject | Select-Object -Exp Hostname -Unique
            # todo: add -WhatIf support to Remove-TecBoxHostnames
            if ($PSCmdlet.ShouldProcess($hostName, 'Remove hostname')) {
                $hostName | Remove-TecBoxHostnames
            }
            
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}