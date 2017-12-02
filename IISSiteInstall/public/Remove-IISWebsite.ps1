#Requires -RunAsAdministrator

function Remove-IISWebsite {
    <#
    .SYNOPSIS
    Removes an IIS Website, it's associated App Pool, file permissions, hosts file and back connection entries
    
    .DESCRIPTION
    Removes an IIS Website, it's associated App Pool, file permissions, hosts file and back connection entries

    When removing file permissions assigned to the identity of the application pool(s) for the site, 
    the following paths will be searched:
    - the phyical file path of the site and all their subfolders and files
    - the phyical file path of all child applications and all their subfolders and files
    - all Temp ASP.Net files folders
    
    .PARAMETER Name
    The name of the IIS Website to add the application to
    
    .PARAMETER KeepBackConnection
    Don't remove the host name(s) for this site from the back connections list?
    
    .PARAMETER KeepHostsFileEntry
    Don't remove the host name(s) for this site from the hosts file?
    
    .EXAMPLE
    Remove-CaccaIISWebsite MySite
    
    .NOTES
    An App Pool that is also assigned to other Websites will NOT be removed
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [switch] $KeepBackConnection,

        [switch] $KeepHostsFileEntry
    )
    
    begin {
        Set-StrictMode -Version 'Latest'
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'
    }
    
    process {
        try {
            $Name = $Name.Trim()
            

            # note: this will produce a warning if site does not exist (this is the desire behaviour - no need to reproduce here)
            $siteInfo = Get-IISSiteHierarchyInfo $Name

            if (!$siteInfo) {
                return
            }

            Get-IISSiteAclPath $Name -Recurse | Where-Object IsShared -eq $false | Remove-CaccaUserFromAcl

            if (!$KeepHostsFileEntry) {
                Get-IISSiteHostsFileEntry $Name | Where-Object IsShared -eq $false | Remove-IISSiteHostsFileEntry
            }

            if (!$KeepBackConnection) {
                Get-IISSiteBackConnection $Name | Where-Object IsShared -eq $false | Remove-IISSiteBackConnection
            }

            Start-IISCommitDelay
            try {

                Remove-IISSite $Name -Confirm:$false

                if ($WhatIfPreference -ne $true) {
                    # note: skipping errors when deleting app pool when that pool is shared by other sites
                    $siteInfo | Select-Object -Exp AppPool_Name -Unique | 
                        Remove-IISAppPool -EA Ignore -Commit:$false
                }

                Stop-IISCommitDelay     
            }
            catch {
                Stop-IISCommitDelay -Commit:$false
                throw
            }
            finally {
                Reset-IISServerManager -Confirm:$false
            }

        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}