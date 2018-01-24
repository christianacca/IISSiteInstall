$projectRoot = Resolve-Path "$PSScriptRoot\.."
$modulePath = Resolve-Path "$projectRoot\*\*.psd1"
$moduleRoot = Split-Path $modulePath

$moduleName = $env:BHProjectName
$moduleRoot = $env:BHModulePath

Describe "PSScriptAnalyzer rule-sets" -Tag Build {

    $rulesToExclude = @('PSUseToExportFieldsInManifest', 'PSShouldProcess')
    $Rules = Get-ScriptAnalyzerRule | where RuleName -NotIn $rulesToExclude
    $scripts = Get-ChildItem $moduleRoot -Include *.ps1, *.psm1, *.psd1 -Recurse | where fullname -notmatch 'classes'

    foreach ( $Script in $scripts ) 
    {
        Context "Script '$($script.FullName)'" {

            foreach ( $rule in $rules )
            {
                It "Rule [$rule]" {

                    (Invoke-ScriptAnalyzer -Path $script.FullName -IncludeRule $rule.RuleName ).Count | Should Be 0
                }
            }
        }
    }
}

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
        # given
        # Ensure module and it's dependencies NOT already loaded into memory
        Unload-SUT

        # when / then
        {Import-Module ($global:SUTPath) } | Should Not Throw
        Get-Module IISAdministration | Should -Not -Be $null
        Get-Module PreferenceVariables | Should -Not -Be $null
        Get-Module IISSecurity | Should -Not -Be $null
        Get-Module HostNameUtils | Should -Not -Be $null
    }
}