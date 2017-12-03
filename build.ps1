<#
.Description
Installs and loads all the required modules for the build.
Derived from scripts written by Warren F. (RamblingCookieMonster)
#>

[cmdletbinding()]
param ($Task = 'Default')
Write-Output "Starting build"

if (-not (Get-PackageProvider -Name Nuget -EA SilentlyContinue))
{
    Write-Output '  Installing the latest version of PS package provider'
    Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
}

# Register custom PS Repo (currently required for forked vs of PSDepend)
$dependenciesRepository = 'christianacca-ps'
if (-not(Get-PSRepository -Name $dependenciesRepository -EA SilentlyContinue))
{
    Write-Output "  Registering custom PS Repository '$dependenciesRepository'"    
    $repo = @{
        Name                  = $dependenciesRepository
        SourceLocation        = 'https://www.myget.org/F/christianacca-ps/api/v2'
        ScriptSourceLocation  = 'https://www.myget.org/F/christianacca-ps/api/v2/'
        PublishLocation       = 'https://www.myget.org/F/christianacca-ps/api/v2/package'
        ScriptPublishLocation = 'https://www.myget.org/F/christianacca-ps/api/v2/package/'
        InstallationPolicy    = 'Trusted'
    }
    Register-PSRepository @repo
}

# todo: publish to PSGallery
Set-Item Env:\PublishRepo -Value $dependenciesRepository

# Grab nuget bits, install modules, set build variables, start build.
Write-Output "  Install And Import Dependent Modules"
Write-Output "    Build Modules"
if (-not(Get-InstalledModule PSDepend -RequiredVersion 0.1.56.3 -EA SilentlyContinue))
{
    Install-Module PSDepend -RequiredVersion 0.1.56.3 -Repository $dependenciesRepository
}
Invoke-PSDepend -Path "$PSScriptRoot\build.depend.psd1" -Install -Import -Force

Write-Output "    SUT Modules"
Invoke-PSDepend -Path "$PSScriptRoot\test.depend.psd1" -Install -Import -Force

Set-BuildEnvironment

Write-Output "  InvokeBuild"
Invoke-Build $Task -Result result
if ($Result.Error)
{
    exit 1
}
else 
{
    exit 0
}