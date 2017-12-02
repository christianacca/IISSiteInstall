$modulePath = Resolve-Path "$PSScriptRoot\..\*\*.psd1"
$moduleName = Split-Path (Split-Path $modulePath) -Leaf

Get-Module $moduleName -All | Remove-Module
Import-Module $modulePath

$testSiteName = 'DeleteMeSite5'
$testAppPoolName = "$testSiteName-AppPool"
$testAppPoolUsername = "IIS AppPool\$testSiteName-AppPool"

Describe 'Remove-IISWebApp' {

    function GetAppPoolPermission {
        param(
            [string] $Path,
            [string] $Username
        )
        (Get-Item $Path).GetAccessControl('Access').Access |
            Where-Object { $_.IsInherited -eq $false -and $_.IdentityReference -eq $Username }
    }

    BeforeAll {
        # given
        $sitePath = "$TestDrive\$testSiteName"
        New-CaccaIISWebsite $testSiteName $sitePath -AppPoolName $testAppPoolName -Force
    }

    AfterAll {
        Remove-CaccaIISWebsite $testSiteName -Confirm:$false
    }

    It 'Should not throw if website does not exist' {
        { Remove-CaccaIISWebApp NonExistantSite MyApp -EA Stop; $true } | Should -Be $true
    }

    It 'Should not throw if web app does not exist' {
        { Remove-CaccaIISWebApp $testSiteName NonExistantApp -EA Stop; $true } | Should -Be $true
    }

    Context 'App shares app pool of site' {

        BeforeAll {
            # given
            $appName = 'MyApp'
            New-CaccaIISWebApp $testSiteName $appName

            # when
            Remove-CaccaIISWebApp $testSiteName $appName
        }

        It 'Should remove existing app' {
            # then
            Get-IISSite $testSiteName | select -Exp Applications | ? Path -eq "/$appName" | Should -BeNullOrEmpty
        }

        It 'Should NOT remove site apppool' {
            # then
            Get-IISAppPool $testAppPoolName | Should -Not -BeNullOrEmpty
        }

        It 'Should remove file permissions to Web app path' {
            # then
            GetAppPoolPermission "$sitePath\$appName" $testAppPoolUsername | Should -BeNullOrEmpty
        }

        It 'Should NOT remove file permissions to Temp ASP.Net files folder' {
            # then
            Get-CaccaTempAspNetFilesPaths | % {
                GetAppPoolPermission $_ $testAppPoolUsername | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Non-Shared app pool' {
        
        BeforeAll {
            # given
            $appPoolName = 'NonSharedPool'
            $appPoolUsername = "IIS AppPool\$appPoolName"
            $appName = 'MyApp'
            New-CaccaIISWebApp $testSiteName $appName -AppPoolName $appPoolName

            # we need to work with SID's rather than friendly usernames, as friendly names are not available once
            # app pool is deleted
            $appPoolSid = (GetAppPoolPermission "$sitePath\$appName" $appPoolUsername).IdentityReference | % {
                $_.Translate([System.Security.Principal.SecurityIdentifier]).Value
            }

            # when
            Remove-CaccaIISWebApp $testSiteName $appName
        }
        
        It 'Should remove existing app' {
            # then
            Get-IISSite $testSiteName | select -Exp Applications | ? Path -eq "/$appName" | Should -BeNullOrEmpty
        }
        
        It 'Should remove apppool' {
            # then
            Get-IISAppPool $appPoolName -WA SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'Should remove file permissions to Web app path' {
            # then
            GetAppPoolPermission "$sitePath\$appName" $appPoolSid | Should -BeNullOrEmpty
        }

        It 'Should remove file permissions to Temp ASP.Net files folder' {
            # then
            Get-CaccaTempAspNetFilesPaths | % {
                GetAppPoolPermission $_ $appPoolSid | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Non-Shared app pool, specific user assigned as AppPool identity' {
        
        BeforeAll {
            # given...

            $testLocalUser = "PesterTestUser-$(Get-Random -Maximum 10000)"
            $domainQualifiedTestLocalUser = "$($env:COMPUTERNAME)\$testLocalUser"
            $pswd = ConvertTo-SecureString '(pe$ter4powershell)' -AsPlainText -Force
            $creds = [PsCredential]::new($domainQualifiedTestLocalUser, $pswd)
            New-LocalUser $testLocalUser -Password $pswd

            $appPoolName = 'NonSharedPool'
            $appPoolUsername = "IIS AppPool\$appPoolName"
            $appName = 'MyApp'
            New-CaccaIISWebApp $testSiteName $appName -AppPoolName $appPoolName -AppPoolConfig {
                $_ | Set-CaccaIISAppPoolUser $creds -Commit:$false
            }

            # when
            Remove-CaccaIISWebApp $testSiteName $appName
        }

        AfterAll {
            Remove-LocalUser $testLocalUser
        }

        It 'Should remove file permissions to Web app path' {
            # then
            GetAppPoolPermission "$sitePath\$appName" $domainQualifiedTestLocalUser | Should -BeNullOrEmpty
        }

        It 'Should remove file permissions to Temp ASP.Net files folder' {
            # then
            Get-CaccaTempAspNetFilesPaths | % {
                GetAppPoolPermission $_ $domainQualifiedTestLocalUser | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Additional file permissions' {
        BeforeAll {
            # given...

            $modifyPath = "$sitePath\MyApp\App_Data"
            New-Item $modifyPath -ItemType Directory
            
            $exePath = "$sitePath\MyApp\SomeExe.exe"
            New-Item $exePath -ItemType File
            
            $appPoolName = 'NonSharedPool2'
            $appPoolUsername = "IIS AppPool\$appPoolName"
            $appName = 'MyApp'
            New-CaccaIISWebApp $testSiteName $appName -AppPoolName $appPoolName -ModifyPaths $modifyPath -ExecutePaths $exePath

            
            # we need to work with SID's rather than friendly usernames, as friendly names are not available once
            # app pool is deleted
            $appPoolSid = (GetAppPoolPermission "$sitePath\$appName" $appPoolUsername).IdentityReference | % {
                $_.Translate([System.Security.Principal.SecurityIdentifier]).Value
            }


            # when
            Remove-CaccaIISWebApp $testSiteName $appName -ModifyPaths $modifyPath -ExecutePaths $exePath
        }

        It 'Should remove file permissions to -ModifyPaths' {
            # then
            GetAppPoolPermission $modifyPath $appPoolSid | Should -BeNullOrEmpty
        }

        It 'Should remove file permissions to -ExecutePaths' {
            # then
            GetAppPoolPermission $exePath $appPoolSid | Should -BeNullOrEmpty
        }
    }

    Context 'Missing ModifyPath' {
        BeforeAll {
            # given
            $appName = 'MyApp10'
            New-CaccaIISWebApp $testSiteName $appName -Force

            $threw = $false
            try {
                Remove-CaccaIISWebApp $testSiteName $appName -ModifyPaths "$TestDrive\MissingPath" -EA Stop
            }
            catch {
                $threw = $true
            }
        }

        It 'Should not throw' {
            # then
            $threw | Should -Be $false
        }

        It 'Should continue to remove Web App' {
            # then
            Get-IISSite $testSiteName | select -Exp Applications | ? Path -eq "/$appName" | Should -BeNullOrEmpty
        }
    }
}