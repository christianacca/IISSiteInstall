#Requires -RunAsAdministrator

function Remove-IISSiteBackConnection {
    <#
    .SYNOPSIS
    Removes the host name(s) from the back connections registry setting
    
    .DESCRIPTION
    Removes the host name from the back connections registry setting
    
    .PARAMETER InputObject
    The backconnection entry to remove
    
    .PARAMETER Force
    Remove even if the host name is assigned to more than one site
    
    .EXAMPLE
    Get-CaccaIISSiteBackConnection MySite | Remove-IISSiteBackConnection
    
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
            # todo: add -WhatIf support to Remove-TecBoxBackConnectionHostNames
            if ($PSCmdlet.ShouldProcess($hostName, 'Remove hostname')) {
                $hostName | Remove-TecBoxBackConnectionHostNames
            }
            
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}