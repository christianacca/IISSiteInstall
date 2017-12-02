<#
.Description
Installs and loads all the required modules for the build.
Derived from scripts written by Warren F. (RamblingCookieMonster)
#>

[cmdletbinding()]
param ($Task = 'Default')
Write-Output "Starting build"

# Grab nuget bits, install modules, set build variables, start build.
Write-Output "  Install And Import Dependent Modules"
Write-Output "    Build Modules"
if (-not(Get-InstalledModule PSDepend -RequiredVersion 0.1.56.3 -EA SilentlyContinue))
{
    Install-Module PSDepend -RequiredVersion 0.1.56.3 -Repository christianacca-ps
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