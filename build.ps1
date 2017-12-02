<#
.Description
Installs and loads all the required modules for the build.
Derived from scripts written by Warren F. (RamblingCookieMonster)
#>

[cmdletbinding()]
param ($Task = 'Default')
Write-Output "Starting build"

# Register repo (used to publish)
$publishRepository = 'christianacca-ps'
Set-Item Env:\PublishRepo -Value $publishRepository
if (-not(Get-PSRepository -Name $publishRepository -EA SilentlyContinue))
{
    Write-Output "  Registering custom PS Repository '$publishRepository'"
    Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
    Import-Module PowerShellGet
    
    $repo = @{
        Name                  = $publishRepository
        SourceLocation        = 'https://www.myget.org/F/christianacca-ps/api/v2'
        ScriptSourceLocation  = 'https://www.myget.org/F/christianacca-ps/api/v2/'
        PublishLocation       = 'https://www.myget.org/F/christianacca-ps/api/v2/package'
        ScriptPublishLocation = 'https://www.myget.org/F/christianacca-ps/api/v2/package/'
        InstallationPolicy    = 'Trusted'
    }
    Register-PSRepository @repo
}

# Grab nuget bits, install modules, set build variables, start build.
Write-Output "  Install And Import Dependent Modules"
Write-Output "    Build Modules"
if (-not(Get-InstalledModule PSDepend -RequiredVersion 0.1.56.3 -EA SilentlyContinue))
{
    Install-Module PSDepend -RequiredVersion 0.1.56.3 -Repository $publishRepository
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