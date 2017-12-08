$projectRoot = Resolve-Path "$PSScriptRoot\.."
$modulePath = Resolve-Path "$projectRoot\*\*.psd1"
$moduleRoot = Split-Path $modulePath

$moduleName = $env:BHProjectName
$moduleRoot = $env:BHModulePath

Describe "General project validation: $moduleName"  -Tag Build, Unit {

    $scripts = Get-ChildItem $moduleRoot -Include *.ps1, *.psm1, *.psd1 -Recurse

    # TestCases are splatted to the script so we need hashtables
    $testCase = $scripts | Foreach-Object {@{file = $_}}         
    It "Script <file> should be valid powershell" -TestCases $testCase {
        param($file)

        $file.fullname | Should Exist

        $contents = Get-Content -Path $file.fullname -ErrorAction Stop
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize($contents, [ref]$errors)
        $errors.Count | Should Be 0
    }

    It "Module '$moduleName' auto-imports dependencies" {
        # given...

        # Ensure module and it's dependencies NOT already loaded into memory
        Get-Module $moduleName -All | Remove-Module -Force
        Get-Module IISSecurity -All | Remove-Module -Force
        Get-Module HostNameUtils -All | Remove-Module -Force
        Get-Module IISAdministration -All | Remove-Module -Force
        Get-Module PreferenceVariables -All | Remove-Module -Force

        # we've lost the environment variable set by PSDepend (not sure why)... restoring
        $installPath = Resolve-Path "$PSScriptRoot\..\_build-cache\"
        Set-Item -Path Env:\PSModulePath -Value "$installPath;$($env:PSModulePath)"


        # when / then
        {Import-Module ($global:SUTPath) } | Should Not Throw
        Get-Module IISAdministration | Should -Not -Be $null
        Get-Module PreferenceVariables | Should -Not -Be $null
        Get-Module IISSecurity | Should -Not -Be $null
        Get-Module HostNameUtils | Should -Not -Be $null
    }
}