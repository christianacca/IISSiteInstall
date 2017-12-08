<#
.Description
Installs and loads all the required modules for the build.
Derived from scripts written by Warren F. (RamblingCookieMonster)
#>

[cmdletbinding()]
param ($Task = 'Default')
if ($Task -ne 'init') 
{
    Write-Output "Starting build"
} 
else 
{
    Write-Output "Starting build (init only)"
}

if (-not (Get-PackageProvider -Name Nuget -EA SilentlyContinue))
{
    Write-Output '  Install Nuget PS package provider'
    Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
}

# Register custom PS Repo (currently required for forked vs of PSDepend)
$dependenciesRepository = 'christianacca-ps'
.\build-helpers\Register-PSRepositoryIfMissing $dependenciesRepository

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

if (-not (Get-Item env:\BH*)) 
{
    Set-BuildEnvironment
}
$global:SUTPath = $env:BHPSModuleManifest

if ($Task -eq 'init') 
{
    Write-Output "Build succeeded (init only)"
    return
}

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