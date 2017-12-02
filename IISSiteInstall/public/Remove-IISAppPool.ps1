#Requires -RunAsAdministrator

function Remove-IISAppPool {
    <#
    .SYNOPSIS
    Removes an IIS AppPool and associated file permissions
    
    .DESCRIPTION
    Removes an IIS AppPool and associated file permissions.

    File permissions on the Temp ASP.Net files will be removed.

    Where the pool uses ApplicationPoolIdentity, file permissions for this identity will be
    removed from all physical paths of all Website/Application that is assigned to this pool
    
    .PARAMETER Name
    The name of the pool to remove
    
    .PARAMETER InputObject
    The instance of the pool to remove
    
    .PARAMETER Force
    Delete the pool even if it's assigned to a Site and/or application
    
    .PARAMETER Commit
    Save changes to IIS immediately? Defaults to true
    
    .EXAMPLE
    Remove-CaccaIISAppPool MyAppPool
    
    .NOTES
    Exception thrown when:
    * Application Pool is assigned to one or more sites/applications and -Force is NOT supplied
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Name')]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Name', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Object', Position = 0)]
        [Microsoft.Web.Administration.ApplicationPool] $InputObject,

        [switch] $Force,

        [switch] $Commit
    )
    
    begin {
        Set-StrictMode -Version 'Latest'
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        if (!$PSBoundParameters.ContainsKey('Commit')) {
            $Commit = $true
        }

        $sitesAclPaths = Get-IISSiteAclPath

        $existingSiteInfo = if ($Force) {
            @()
        }
        else {
            Get-IISSiteHierarchyInfo
        }
    }
    
    process {
        try {

            [Microsoft.Web.Administration.ServerManager] $manager = Get-IISServerManager

            $pool = if ($InputObject) {
                $InputObject
            }
            else {
                $instance = $manager.ApplicationPools[$Name]
                if (!$instance) {
                    throw "Cannot delete AppPool, '$Name' does not exist"
                }
                $instance
            }            

            $inUse = $existingSiteInfo | Where-Object AppPool_Name -eq $Name
            if ($inUse) {
                throw "Cannot delete AppPool, '$Name' is used by one or more Web applications/sites"
            }

            $appPoolUsername = Get-IISAppPoolUsername $pool
            
            $appPoolIdentityCount = Get-IISAppPool | Get-IISAppPoolUsername | Where-Object { $_ -eq $appPoolUsername } |
                Measure-Object | Select-Object -Exp Count
            $isNonSharedIdentity = $appPoolIdentityCount -lt 2
            $isAppPoolIdentity = $pool.ProcessModel.IdentityType -eq 'ApplicationPoolIdentity'

            $allAclPaths = @()
            if ($isAppPoolIdentity) {
                $allAclPaths += $sitesAclPaths
            }
            if ($isNonSharedIdentity) {
                $allAclPaths += Get-CaccaTempAspNetFilesPaths | ForEach-Object {
                    [PsCustomObject] @{
                        Path = $_
                        IdentityReference = $appPoolUsername
                    }
                }
            }
            $allAclPaths | Where-Object IdentityReference -eq $appPoolUsername | Remove-CaccaUserFromAcl

            if ($Commit) {
                Start-IISCommitDelay
            }
            try {

                if ($PSCmdlet.ShouldProcess($Name, 'Remove App pool')) {
                    $manager.ApplicationPools.Remove($pool)
                }
                
                if ($Commit) {
                    Stop-IISCommitDelay
                }
            }
            catch {
                if ($Commit) {
                    Stop-IISCommitDelay -Commit:$false
                }
                throw
            }
            finally {
                if ($Commit) {
                    # make sure subsequent scripts will not fail because the ServerManger is now readonly
                    Reset-IISServerManager -Confirm:$false
                }
            }

        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}