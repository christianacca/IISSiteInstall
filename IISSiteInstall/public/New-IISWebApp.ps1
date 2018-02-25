#Requires -RunAsAdministrator

function New-IISWebApp
{
    <#
    .SYNOPSIS
    Creates a new IIS Web application + App Pool, assigning it least-privilege file permissions
    
    .DESCRIPTION
    Creates a new IIS Web application + App Pool, setting least privilege file permissions to 
    the useraccount configured as the identity of the IIS AppPool.

    These bare minium file permissions include:
    - Path: Read 'This folder', file and subfolder permissions (inherited)
    - Temporary ASP.NET Files: Read 'This folder', file and subfolder permissions (inherited)
    - ModifyPaths: modify 'This folder', file and subfolder permissions (inherited)
    - ExecutePaths: read+execute file (no inherit)

    .PARAMETER SiteName
    The name of the IIS Website to add the application to
    
    .PARAMETER Name
    The logical path name of the application (eg MyApp, /MyApp/NestedApp)
    
    .PARAMETER Path
    The physcial path of the application. Defaults to using 'Name' as a sub folder of the physical site path.
    Path will be created if missing.
    
    .PARAMETER Config
    A script block that will receive the instance of the application being created
    
    .PARAMETER AppPoolName
    The name of the AppPool to assign and create if missing.
    If not supplied, will default to use the AppPool of the IIS Website
    
    .PARAMETER AppPoolConfig
    A script block that will receive the instance of the pool to be used by the application
    
    .PARAMETER ModifyPaths
    Additional paths to grant modify (inherited) permissions. Path(s) relative to 'Path' can be supplied

    .PARAMETER ExecutePaths
    Additional paths to grant read+excute permissions. Path(s) relative to 'Path' can be supplied
    
    .PARAMETER Force
    Overwrite any existing application?
    
    .EXAMPLE
    New-CaccaIISWebApp MySite MyNewApp

    Description
    -----------
    Create child Web application of MySite, with the physical path set as a subfolder of the Website
    (eg C:\inetpub\sites\MySite\MyNewApp), and an App Pool assigned to that of the Website

    .EXAMPLE
    New-CaccaIISWebApp MySite MyNewApp -AppPoolName MyNewPool -AppPoolConfig {
        $_ | Set-CaccaIISAppPoolUser -IdentityType ApplicationPoolIdentity -Commit:$false
    }

    Description
    -----------
    As above except assigns, creating as necessary, an App Pool named 'MyNewPool' and
    configuring that pool to use the ApplicationPoolIdentity as it's identity

    .EXAMPLE
    New-CaccaIISWebApp MySite MyNewApp C:\Some\Path\Else -Config {
        Unlock-CaccaIISAnonymousAuth -Location "$SiteName$($_.Path)" -Commit:$false
    }

    Description
    -----------
    Create child Web application of MySite, with the physical path set to C:\Some\Path\Else.

    Uses -Config to supply a script block to perform custom configuration of the application. In this
    example, using the Unlock-CaccaIISAnonymousAuth cmdlet from the IISConfigUnlock module

    .EXAMPLE
    New-CaccaIISWebApp MySite MyNewApp -ModifyPaths 'App_Data', 'logs' -ExecutePaths bin\Some.exe

    Description
    -----------
    Configures additional file permissions to the useraccount configured as the identity of the IIS AppPool
    
    .NOTES
    Exception thrown when:
    * Application 'Name' already exists and -Force is NOT supplied
    * The Application Pool 'AppPoolName' is used by another Website
    * Using 'AppPoolConfig' to configure an Application pool that is already assigned to another Application and/or Website
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $SiteName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Path,

        [Parameter(ValueFromPipelineByPropertyName)]
        [scriptblock] $Config,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $AppPoolName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [scriptblock] $AppPoolConfig,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]] $ModifyPaths,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]] $ExecutePaths,

        [switch] $Force
    )
    
    begin
    {
        Set-StrictMode -Version 'Latest'
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        function GetAppPoolOtherAppCount
        {
            param (
                [string] $SiteName,
                [string] $ThisAppName,
                [string] $AppPoolName
            )
            Get-IISSiteHierarchyInfo | 
                Where-Object { $_.AppPool_Name -eq $AppPoolName -and $_.Site_Name -eq $SiteName -and $_.App_Path -ne $ThisAppName } |
                Select-Object App_Path -Unique |
                Measure-Object | Select-Object -Exp Count
        }
    }
    
    process
    {
        try
        {
            Write-Information "Create Web application '$Name' under site '$SiteName'"

            $SiteName = $SiteName.Trim()
            $Name = $Name.Trim()
            if (!$Name.StartsWith('/'))
            {
                $Name = '/' + $Name
            }
            if ($null -eq $Config)
            {
                $Config = {}
            }
            if ($null -eq $ModifyPaths)
            {
                $ModifyPaths = @()
            }
            if ($null -eq $ExecutePaths)
            {
                $ExecutePaths = @()
            }


            $site = Get-IISSite $SiteName
            if (!$site)
            {
                return
            }

            $qualifiedAppName = "$SiteName$Name"

            $existingApp = $site.Applications[$Name]
            if ($existingApp -and !$Force)
            {
                throw "Web Application '$qualifiedAppName' already exists. To overwrite you must supply -Force"
            }

            $rootApp = $site.Applications['/']
            if ([string]::IsNullOrWhiteSpace($AppPoolName))
            {
                $AppPoolName = $rootApp.ApplicationPoolName
            }

            if ((GetAppPoolOtherSiteCount $SiteName $AppPoolName) -gt 0)
            {
                throw "Cannot create Web Application - AppPool '$AppPoolName' is in use on another site"
            }
            if ($AppPoolConfig -and (GetAppPoolOtherAppCount $SiteName $Name $AppPoolName) -gt 0)
            {
                throw "Cannot configure AppPool '$AppPoolName' - it belongs to another Web Application and/or this site"
            }

            $childPath = if ([string]::IsNullOrWhiteSpace($Path))
            {
                $sitePath = $rootApp.VirtualDirectories['/'].PhysicalPath
                Join-Path $sitePath $Name
            }
            else
            {
                $Path
            }
            
            $isPathExists = Test-Path $childPath
            if (!$isPathExists -and $PSCmdlet.ShouldProcess($childPath, 'Create Web Application physical path'))
            {
                New-Item $childPath -ItemType Directory -WhatIf:$false | Out-Null
            }

            if ($existingApp)
            {
                Write-Information "Existing Web application '$Name' found"
                Remove-IISWebApp $SiteName $Name -ModifyPaths $ModifyPaths -ExecutePaths $ExecutePaths
            }

            # Remove-IISWebApp has just committed changes making our $site instance read-only, therefore fetch another one
            $site = Get-IISSite $SiteName

            Start-IISCommitDelay
            try
            {
                $pool = Get-IISAppPool $AppPoolName -WA SilentlyContinue
                if (!$pool)
                {
                    $pool = New-IISAppPool $AppPoolName -Commit:$false
                }

                if ($AppPoolConfig -and $WhatIfPreference -eq $false)
                {
                    $pool | ForEach-Object $AppPoolConfig | Out-Null
                }

                if ($PSCmdlet.ShouldProcess($qualifiedAppName, 'Create Web Application'))
                {
                    $app = $site.Applications.Add($Name, $childPath)
                    $app.ApplicationPoolName = $AppPoolName

                    $app | ForEach-Object $Config
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

            if ($WhatIfPreference -eq $true -and !$isPathExists)
            {
                # Set-CaccaIISSiteAcl requires path to exist
            }
            else
            {
                $appPoolIdentity = Get-IISAppPool $AppPoolName | Get-IISAppPoolUsername
                if ($WhatIfPreference -eq $true -and [string]::IsNullOrWhiteSpace($appPoolIdentity))
                {
                    $appPoolIdentity = "IIS AppPool\$AppPoolName"
                }
                $appAclParams = @{
                    AppPath           = $childPath
                    AppPoolIdentity   = $appPoolIdentity
                    ModifyPaths       = $ModifyPaths
                    ExecutePaths      = $ExecutePaths
                    CreateMissingPath = $true
                }
                Set-CaccaIISSiteAcl @appAclParams
            }

            (Get-IISSite $SiteName).Applications[$Name]
        }
        catch
        {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}