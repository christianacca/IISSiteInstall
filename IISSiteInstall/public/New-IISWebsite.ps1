#Requires -RunAsAdministrator

function New-IISWebsite
{
    <#
    .SYNOPSIS
    Creates a new IIS Website + App Pool, assigning it least-privilege file permissions
    
    .DESCRIPTION
    Creates a new IIS Web application + App Pool, setting least privilege file permissions to 
    the useraccount configured as the identity of the IIS AppPool.

    These bare minium file permissions include:
    - Path: Read 'This folder', file and subfolder permissions (inherited)
        - Note: use 'SiteShellOnly' to reduce these permissions to just the folder and files but NOT subfolders
    - Temporary ASP.NET Files: Read 'This folder', file and subfolder permissions (inherited)
    - ModifyPaths: modify 'This folder', file and subfolder permissions (inherited)
    - ExecutePaths: read+execute file (no inherit)s
    
    .PARAMETER Name
    The name of the IIS Website to add the application to
    
    .PARAMETER Path
    The physcial path of the Website. Defaults to using "C:\inetpub\sites\$Name". Path will be created if missing.
    
    .PARAMETER Port
    The port number to use for the default site binding. Defaults to 80
    
    .PARAMETER Protocol
    The protocol to use for the default site binding. Defaults to 'http'
    
    .PARAMETER HostName
    Optional hostname to use for the default site binding.
    See also 'HostsFileIPAddress' and 'AddHostToBackConnections' parameters
    
    .PARAMETER Config
    A script block that will receive the instance of the Website being created
    
    .PARAMETER ModifyPaths
    Additional paths to grant modify (inherited) permissions. Path(s) relative to 'Path' can be supplied

    .PARAMETER ExecutePaths
    Additional paths to grant read+excute permissions. Path(s) relative to 'Path' can be supplied
    
    .PARAMETER SiteShellOnly
    Grant permissions used for 'Path' to only that folder and it's files but NOT subfolders
    
    .PARAMETER AppPoolName
    The name of the AppPool to assign and create if missing. Defaults to "$Name-AppPool"
    
    .PARAMETER AppPoolConfig
    A script block that will receive the instance of the pool to be used by the application
    
    .PARAMETER HostsFileIPAddress
    Resolve hostname(s) used by the site bindings to an IP address (stores a record in the hosts file on this computer)
    
    .PARAMETER AddHostToBackConnections
    Register hostname(s) used by the site bindings as a BackConnection registry entry to bypass the loopback security 
    check for this name(s)
    
    .PARAMETER Force
    Overwrite any existing Website?
    
    .EXAMPLE
    New-CaccaIISWebsite MySite

    Description
    -----------
    Create a Website named MySite, with the physical path set to C:\inetpub\sites\MySite.
    Assigns an App Pool named MySite-AppPool, creating the pool if not already present.
    Binds the site to port 80 over http

    .EXAMPLE
    New-CaccaIISWebsite MySite -AppPoolName MyNewPool -AppPoolConfig {
        $_ | Set-CaccaIISAppPoolUser -IdentityType ApplicationPoolIdentity -Commit:$false
    }

    Description
    -----------
    As above except assigns, creating as necessary, an App Pool named 'MyNewPool' and
    configuring that pool to use the ApplicationPoolIdentity as it's identity
    
    .EXAMPLE
    New-CaccaIISWebsite MySite C:\Some\Path\Else -Config {
        Unlock-CaccaIISAnonymousAuth -Location $_.Name -Commit:$false
    }

    Description
    -----------
    Create Website named MySite, with the physical path set to C:\Some\Path\Else.

    Uses -Config to supply a script block to perform custom configuration of the Website. In this
    example, using the Unlock-CaccaIISAnonymousAuth cmdlet from the IISConfigUnlock module

    .EXAMPLE
    New-CaccaIISWebsite MySite -AppPoolName MyNewPool -AppPoolConfig {
        $_ | Set-CaccaIISAppPoolUser -IdentityType ApplicationPoolIdentity -Commit:$false
    }

    Description
    -----------
    As above except assigns, creating as necessary, an App Pool named 'MyNewPool' and
    configuring that pool to use the ApplicationPoolIdentity as it's identity
    
    .EXAMPLE
    New-CaccaIISWebsite MySite -ModifyPaths 'App_Data', 'logs' -ExecutePaths bin\Some.exe

    Description
    -----------
    Configures additional file permissions to the useraccount configured as the identity of the IIS AppPool

    .EXAMPLE
    New-CaccaIISWebsite MySite -HostsFileIPAddress 127.0.0.1 -Hostname dev-mysite -AddHostToBackConnections -Config {
        New-IISSiteBinding $_.Name ':8080:local-mysite' http
    }

    Description
    -----------
    Configures the site with an additional binding to port 8080, host name 'local-mysite'. Ensures 'dev-mysite'
    and 'local-mysite' resolve to 127.0.0.1 on this computer whilst ensuring these host names bypass the loopback
    security check

    .NOTES
    Exception thrown when:
    * Website 'Name' already exists and -Force is NOT supplied
    * The Application Pool 'AppPoolName' is used by another Website
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Path,

        [ValidateRange(0, 65535)]
        [int] $Port = 80,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateSet('http', 'https')]
        [string] $Protocol = 'http',

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $HostName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [scriptblock] $Config,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]] $ModifyPaths,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]] $ExecutePaths,

        [switch] $SiteShellOnly,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $AppPoolName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [scriptblock] $AppPoolConfig,

        [string] $HostsFileIPAddress,

        [switch] $AddHostToBackConnections,

        [switch] $Force
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
            Write-Information "Create website '$Name'"

            $Name = $Name.Trim()
            if ([string]::IsNullOrWhiteSpace($Path))
            {
                $Path = "C:\inetpub\sites\$Name"
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
            if ([string]::IsNullOrWhiteSpace($AppPoolName))
            {
                $AppPoolName = "$Name-AppPool"
            }
            if ($null -eq $AppPoolConfig)
            {
                $AppPoolConfig = {}
            }

            
            $existingSite = Get-IISSite $Name -WA SilentlyContinue
            if ($existingSite -and !$Force)
            {
                throw "Cannot create site - site '$Name' already exists. To overwrite you must supply -Force"
            }

            if ((GetAppPoolOtherSiteCount $Name $AppPoolName) -gt 0)
            {
                throw "Cannot create site - AppPool '$AppPoolName' is in use on another site"
            }

            $isPathExists = Test-Path $Path
            if (!$isPathExists -and $PSCmdlet.ShouldProcess($Path, 'Create Web Site physical path'))
            {
                New-Item $Path -ItemType Directory -WhatIf:$false | Out-Null
            }

            if ($existingSite)
            {
                Write-Information "Existing website '$Name' found"
                Remove-IISWebsite $Name -Confirm:$false
            }

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
    
                $site = $null
                if ($PSCmdlet.ShouldProcess($Name, 'Create Web Site'))
                {
                    $bindingInfo = "*:$($Port):$($HostName)"
                    [Microsoft.Web.Administration.Site] $site = New-IISSite $Name $Path $bindingInfo $Protocol -Passthru
                    $site.Applications["/"].ApplicationPoolName = $AppPoolName

                    $site | ForEach-Object $Config

                    $allHostNames = $site.Bindings | Select-Object -Exp Host -Unique
                    
                    if (![string]::IsNullOrWhiteSpace($HostsFileIPAddress) -and $PSCmdlet.ShouldProcess($allHostNames, 'Add hosts file entry'))
                    {
                        Write-Information "Add '$allHostNames' to hosts file"
                        $allHostNames | Add-TecBoxHostnames -IPAddress $HostsFileIPAddress
                    }
                    
                    if ($AddHostToBackConnections -and $PSCmdlet.ShouldProcess($allHostNames, 'Add back connection'))
                    {
                        Write-Information "Add '$allHostNames' to backconnection registry value"
                        $allHostNames | Add-TecBoxBackConnectionHostNames
                    }
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

                Write-Information "Granting file permissions to '$appPoolIdentity'"
                $siteAclParams = @{
                    SitePath        = $Path
                    AppPoolIdentity = $appPoolIdentity
                    ModifyPaths     = $ModifyPaths
                    ExecutePaths    = $ExecutePaths
                    SiteShellOnly   = $SiteShellOnly
                }
                Set-CaccaIISSiteAcl @siteAclParams
            }

            Get-IISSite $Name
        }
        catch
        {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}