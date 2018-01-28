#Requires -RunAsAdministrator

function Remove-IISWebApp
{
    <#
    .SYNOPSIS
    Removes an IIS Web Application, it's associated App Pool and file permissions
    
    .DESCRIPTION
    Removes an IIS Web Application, it's associated App Pool and file permissions.

    By default just the file permissions assigned to the phyical file path of the web 
    application and Temp ASP.Net files will be removed.

    Use 'ModifyPaths' and/or 'ExecutePaths' to supply additional paths to remove file 
    permissions from. Typically these paths are the ones supplied to the New-CaccaIISWebApp 
    cmdlet.
    
    .PARAMETER SiteName
    The name of the IIS Website to add the application to
    
    .PARAMETER Name
    The logical path name of the application (eg MyApp, /MyApp/NestedApp)
    
    .PARAMETER ModifyPaths
    Additional paths to remove modify file permissions from. Path(s) relative to 'Path' can be supplied

    .PARAMETER ExecutePaths
    Additional paths to remove read+excute permissions from. Path(s) relative to 'Path' can be supplied
    
    .EXAMPLE
    Remove-CaccaIISWebApp MySite MyApp
    
    .NOTES
    An App Pool that is also assigned to other Web Application's will NOT be removed
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $SiteName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $Name,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]] $ModifyPaths,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]] $ExecutePaths
    )
    
    begin
    {
        Set-StrictMode -Version 'Latest'
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'
    }
    
    process
    {
        try
        {
            Write-Information "Remove Web application '$Name'"

            $SiteName = $SiteName.Trim()
            $Name = $Name.Trim()
    
            if (!$Name.StartsWith('/'))
            {
                $Name = '/' + $Name
            }
            if ($null -eq $ModifyPaths)
            {
                $ModifyPaths = @()
            }
            if ($null -eq $ExecutePaths)
            {
                $ExecutePaths = @()
            }


            # note: NOT throwing to be consistent with IISAdministration\Remove-IISSite
            $site = Get-IISSite $SiteName
            if (!$site)
            {
                return
            }

            # note: NOT throwing to be consistent with IISAdministration\Remove-IISSite
            $app = $site.Applications[$Name]
            if (!$app)
            {
                Write-Warning "Web Application '$SiteName$Name' does not exist"
                return
            }

            $appPoolIdentity = Get-IISAppPool ($app.ApplicationPoolName) | Get-IISAppPoolUsername
            $aclInfo = @{
                AppPath             = $app.VirtualDirectories['/'].PhysicalPath
                AppPoolIdentity     = $appPoolIdentity
                ModifyPaths         = $ModifyPaths
                ExecutePaths        = $ExecutePaths
                SkipMissingPaths    = $true
                # file permissions for Temp AP.Net Files folders *might* be shared so must skip removing these
                # cleaning up of orphaned file permissions will happen below when 'Remove-IISAppPool' is run
                SkipTempAspNetFiles = $true
            }
            Remove-CaccaIISSiteAcl @aclInfo

            Start-IISCommitDelay
            try
            {

                if ($PSCmdlet.ShouldProcess("$SiteName$Name", 'Remove Web Application'))
                {
                    $site.Applications.Remove($app)
                }

                if ($WhatIfPreference -ne $true)
                {
                    # note: skipping errors when deleting app pool when that pool is shared by other sites/apps
                    Remove-IISAppPool ($app.ApplicationPoolName) -EA Ignore -Commit:$false
                }

                Stop-IISCommitDelay
            }
            catch
            {
                Stop-IISCommitDelay -Commit:$false
                throw
            }
            finally
            {
                Reset-IISServerManager -Confirm:$false
            }
        }
        catch
        {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}