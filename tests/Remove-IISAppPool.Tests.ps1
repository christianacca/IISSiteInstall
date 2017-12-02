$modulePath = Resolve-Path "$PSScriptRoot\..\*\*.psd1"
$moduleName = Split-Path (Split-Path $modulePath) -Leaf

Get-Module $moduleName -All | Remove-Module
Import-Module $modulePath

$testSiteName = 'DeleteMeSite'
$tempAppPool = 'TestAppPool'
$tempAppPoolUsername = "IIS AppPool\$tempAppPool"

Describe 'Remove-IISAppPool' {

    function GetAppPoolPermission {
        param(
            [string] $Path,
            [string] $Username
        )
        (Get-Item $Path).GetAccessControl('Access').Access |
            Where-Object { $_.IsInherited -eq $false -and $_.IdentityReference -eq $Username }
    }

    # AfterEach {
    #     Reset-IISServerManager -Confirm:$false
    # }

    It 'Should throw if pool does not exist' {
        {Remove-CaccaIISAppPool 'DoesNotExist' -EA Stop} | Should Throw
    }

    Context 'Existing pool (not in use)' {
        BeforeEach {
            # given
            New-CaccaIISAppPool $tempAppPool
            Get-CaccaTempAspNetFilesPaths | % {
                icacls ("$_") /grant:r ("$tempAppPoolUsername" + ':(OI)(CI)R') | Out-Null
            }

            # we need to work with SID's rather than friendly usernames, as friendly names are not available once
            # app pool is deleted
            $tempAspFilePath = (Get-CaccaTempAspNetFilesPaths)[0]
            $appPoolSid = (GetAppPoolPermission $tempAspFilePath $tempAppPoolUsername).IdentityReference | % {
                $_.Translate([System.Security.Principal.SecurityIdentifier]).Value
            }
        }

        It 'Should delete pool' {
            # when
            Remove-CaccaIISAppPool $tempAppPool

            # then
            Get-IISAppPool $tempAppPool -WA SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'Should remove file permissions to Temp ASP.Net files folders' {
            # when
            Remove-CaccaIISAppPool $tempAppPool

            # then
            Get-CaccaTempAspNetFilesPaths | % {
                GetAppPoolPermission $_ $appPoolSid | Should -BeNullOrEmpty
            }
        }

        It '-WhatIf should make no modifications' {
            # when
            Remove-CaccaIISAppPool $tempAppPool -WhatIf

            # then
            Get-IISAppPool $tempAppPool | Should -Not -BeNullOrEmpty
            Get-CaccaTempAspNetFilesPaths | % {
                GetAppPoolPermission $_ $tempAppPoolUsername | Should -Not -BeNullOrEmpty
            }

            # cleanup
            Remove-CaccaIISAppPool $tempAppPool
        }
    }

    Context 'Existing pool in use by Web app' {

        function Cleanup {
            Remove-CaccaIISWebsite $testSiteName -Confirm:$false
        }

        BeforeEach {
            New-CaccaIISWebsite $testSiteName $TestDrive -AppPoolName $tempAppPool -Force
        }

        AfterEach {
            Cleanup
        }

        It 'Should throw' {
            {Remove-CaccaIISAppPool $tempAppPool -EA Stop} | Should Throw
            Get-IISAppPool $tempAppPool | Should -Not -BeNullOrEmpty
        }
    
        It '-Force should allow delete' {
            # we need to work with SID's rather than friendly usernames, as friendly names are not available once
            # app pool is deleted
            $appPoolSid = (GetAppPoolPermission $TestDrive $tempAppPoolUsername).IdentityReference | % {
                $_.Translate([System.Security.Principal.SecurityIdentifier]).Value
            }

            # when
            Remove-CaccaIISAppPool $tempAppPool -Force

            # then
            Get-IISAppPool $tempAppPool -WA SilentlyContinue | Should -BeNullOrEmpty
            GetAppPoolPermission $TestDrive $appPoolSid | Should -BeNullOrEmpty
            Get-CaccaTempAspNetFilesPaths | % {
                GetAppPoolPermission $_ $appPoolSid | Should -BeNullOrEmpty
            }
        }

        It '-WhatIf should make no modifications' {
            # when
            Remove-CaccaIISAppPool $tempAppPool -Force -WhatIf

            # then
            Get-IISAppPool $tempAppPool | Should -Not -BeNullOrEmpty
            GetAppPoolPermission $TestDrive $tempAppPoolUsername | Should -Not -BeNullOrEmpty
        }
    }
}