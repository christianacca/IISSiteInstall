$modulePath = Resolve-Path "$PSScriptRoot\..\*\*.psd1"
$moduleName = Split-Path (Split-Path $modulePath) -Leaf

Get-Module $moduleName -All | Remove-Module
Import-Module $modulePath

$testSiteName = 'DeleteMeSite'
$testAppPoolName = "$testSiteName-AppPool"

Describe 'New-IISWebApp' {

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
        New-CaccaIISWebsite $testSiteName $sitePath -Force -AppPoolName $testAppPoolName
    }

    AfterAll {
        Remove-CaccaIISWebsite $testSiteName -Confirm:$false
    }

    Context 'With defaults' {
    
        BeforeAll {
            $appName = 'MyApp'
            # when
            New-CaccaIISWebApp $testSiteName $appName

            $app = (Get-IISSite $testSiteName).Applications["/$appName"]
        }
    
        AfterAll {
            Remove-CaccaIISWebApp $testSiteName $appName
        }

        It 'Should have created child app' {
            # then
            $app | Should -Not -BeNullOrEmpty
        }

        It 'Should set physical path to be a subfolder of site' {
            # then
            $expectedPhysicalPath = "$sitePath\$appName"
            $expectedPhysicalPath | Should -Exist
            $app.VirtualDirectories["/"].PhysicalPath | Should -Be $expectedPhysicalPath
        }

        It 'Should use the site AppPool' {
            # then
            $app.ApplicationPoolName | Should -Be $testAppPoolName
        }
        
        It 'Should assign file permissions to the physical app path' {
            # then
            $physicalPath = $app.VirtualDirectories["/"].PhysicalPath
            GetAppPoolPermission $physicalPath "IIS AppPool\$testAppPoolName" | Should -Not -BeNullOrEmpty
        }

        It 'Should assign specific user file permissions to Temp ASP.Net files folders' {
            # then
            Get-CaccaTempAspNetFilesPaths | % {
                GetAppPoolPermission $_ "IIS AppPool\$testAppPoolName" | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context '-Path' {
        BeforeAll {
            # given
            $appName = '/MyApp/BlahBlah'
            $appPhysicalPath = "$TestDrive\SomeOtherPath"

            # when
            New-CaccaIISWebApp $testSiteName $appName $appPhysicalPath

            $app = (Get-IISSite $testSiteName).Applications[$appName]
        }
    
        AfterAll {
            Remove-CaccaIISWebApp $testSiteName $appName
        }

        It 'Should use physical path supplied' {
            # then
            $appPhysicalPath | Should -Exist
            $app.VirtualDirectories["/"].PhysicalPath | Should -Be $appPhysicalPath
        }
    }

    Context '-Path already exists' {
        BeforeAll {
            # given
            $appName = '/MyApp/Child2'
            $appPhysicalPath = "$TestDrive\ExistingPath"
            New-Item $appPhysicalPath -ItemType Directory -Force

            # when
            New-CaccaIISWebApp $testSiteName $appName $appPhysicalPath
            
            $app = (Get-IISSite $testSiteName).Applications[$appName]
        }
    
        AfterAll {
            Remove-CaccaIISWebApp $testSiteName $appName
        }

        It 'Should use physical path supplied' {
            # then
            $app.VirtualDirectories["/"].PhysicalPath | Should -Be $appPhysicalPath
        }
    }

    Context '-Config' {
        BeforeEach {
            # given
            $appName = '/MyApp8'
        }
    
        AfterEach {
            Remove-CaccaIISWebApp $testSiteName $appName
        }

        It 'Should receive Application being created' {
            # when
            $appArg = $null
            New-CaccaIISWebApp $testSiteName $appName -Config {
                $appArg = $_
            }
    
            # then
            $appArg | Should -Not -Be $null
            $appArg.Path | Should -Be $appName
        }
    
        It 'Failure should cause app to NOT be created' {

            # when
            New-CaccaIISWebApp $testSiteName $appName -EA SilentlyContinue -Config {
                throw "BANG"
            }

            # then
            (Get-IISSite $testSiteName).Applications[$appName] | Should -BeNullOrEmpty
        }
    }

    Context '-AppPoolName, when pool exists' {
        BeforeAll {
            # given
            $appPoolName = 'NonSharedPool'
            New-CaccaIISAppPool $appPoolName -Force -Config {
                $_.Enable32BitAppOnWin64 = $false
                $_.AutoStart = $false
            }
            $appName = '/MyApp'

            # when
            New-CaccaIISWebApp $testSiteName $appName -AppPoolName $appPoolName

            $app = (Get-IISSite $testSiteName).Applications[$appName]
        }
    
        AfterAll {
            Remove-CaccaIISWebApp $testSiteName $appName
        }

        It 'Should assign existing pool supplied' {
            # then
            $app.ApplicationPoolName | Should -Be $appPoolName
        }

        It 'Should not replace existing pool' {
            # then
            $pool = Get-IISAppPool $appPoolName
            $pool.Enable32BitAppOnWin64 | Should -Be $false
            $pool.AutoStart | Should -Be $false
        }
    }

    Context '-AppPoolName, when pool does NOT exist' {
        BeforeAll {
            # given
            $appPoolName = 'NonSharedPool86'
            $appName = '/MyApp'

            # when
            New-CaccaIISWebApp $testSiteName $appName -AppPoolName $appPoolName

            $app = (Get-IISSite $testSiteName).Applications[$appName]
        }
    
        AfterAll {
            Remove-CaccaIISWebApp $testSiteName $appName
        }

        It 'Should create new pool' {
            # then
            Get-IISAppPool $appPoolName | Should -Not -BeNullOrEmpty
        }

        It 'Should assign new pool to Web application' {
            # then
            $app.ApplicationPoolName | Should -Be $appPoolName
        }
    }

    Context '-AppPoolConfig' {

        Context 'pool exists' {
            BeforeAll {
                # given
                $appPoolName = 'Pool789'
                New-CaccaIISAppPool $appPoolName -Force -Config {
                    $_.Enable32BitAppOnWin64 = $false
                    $_.AutoStart = $false
                }
                $appName = '/MyApp'
    
                # when
                New-CaccaIISWebApp $testSiteName $appName -AppPoolName $appPoolName -AppPoolConfig {
                    $_.AutoStart = $true
                }
            }
        
            AfterAll {
                Remove-CaccaIISWebApp $testSiteName $appName
            }
    
            It 'Should configure existing pool' {
                # then
                $pool = Get-IISAppPool $appPoolName
                $pool.Enable32BitAppOnWin64 | Should -Be $false
                $pool.AutoStart | Should -Be $true
            }
        }
        
        Context 'pool does NOT exist' {
            BeforeAll {
                # given
                $appPoolName = 'NonSharedPool491'
                $appName = '/MyApp'
    
                # when
                New-CaccaIISWebApp $testSiteName $appName -AppPoolName $appPoolName -AppPoolConfig {
                    $_.Enable32BitAppOnWin64 = $false
                    $_.AutoStart = $false
                }
            }
        
            AfterAll {
                Remove-CaccaIISWebApp $testSiteName $appName
            }
    
            It 'Should configure new pool' {
                # then
                $pool = Get-IISAppPool $appPoolName
                $pool.Enable32BitAppOnWin64 | Should -Be $false
                $pool.AutoStart | Should -Be $false
            }
        }

        Context 'pool does NOT exist, setting AppPool identity to specific user' {
            BeforeAll {
                # given...
    
                $testLocalUser = "PesterTestUser-$(Get-Random -Maximum 10000)"
                $domainQualifiedTestLocalUser = "$($env:COMPUTERNAME)\$testLocalUser"
                $pswd = ConvertTo-SecureString '(pe$ter4powershell)' -AsPlainText -Force
                $creds = [PsCredential]::new($domainQualifiedTestLocalUser, $pswd)
                New-LocalUser $testLocalUser -Password $pswd
    
                $appPoolName = 'NonSharedPool86'
                $appName = '/MyApp'
    
    
                # when
                New-CaccaIISWebApp $testSiteName $appName -AppPoolName  $appPoolName -AppPoolConfig {
                    $_ | Set-CaccaIISAppPoolUser $creds -Commit:$false
                }
    
                $app = (Get-IISSite $testSiteName).Applications[$appName]
            }
        
            AfterAll {
                Remove-CaccaIISWebApp $testSiteName $appName
                Get-LocalUser $testLocalUser | Remove-LocalUser
            }
    
            It 'Should use specific user as AppPool identity' {
                # then
                Get-IISAppPool $appPoolName | Get-CaccaIISAppPoolUsername | Should -Be $domainQualifiedTestLocalUser
            }
    
            It 'Should assign specific user file permissions to the physical app path' {
                # then
                $physicalPath = $app.VirtualDirectories["/"].PhysicalPath
                GetAppPoolPermission $physicalPath $domainQualifiedTestLocalUser | Should -Not -BeNullOrEmpty
            }
    
            It 'Should assign specific user file permissions to Temp ASP.Net files folders' {
                # then
                Get-CaccaTempAspNetFilesPaths | % {
                    GetAppPoolPermission $_ $domainQualifiedTestLocalUser | Should -Not -BeNullOrEmpty
                }
            }
        }
    
        Context 'pool assigned to site' {
    
            It 'Should throw' {
                # then
                {New-CaccaIISWebApp $testSiteName MyApp -AppPoolConfig {} -EA Stop} | Should Throw
            }
        }
    }

    Context 'App already exists' {

        BeforeEach {
            # given
            $appPoolName = 'NonSharedPool67814'
            $appName = '/MyApp67814'
            New-CaccaIISWebApp $testSiteName $appName -AppPoolName $appPoolName -AppPoolConfig {
                $_.Enable32BitAppOnWin64 = $false
                $_.AutoStart = $false
            }
        }

        AfterEach {
            Remove-CaccaIISWebApp $testSiteName $appName
        }

        It 'Should throw' {
            # when
            { New-CaccaIISWebApp $testSiteName $appName -EA Stop } | Should Throw
        }

        It '-Force should replace existing app' {
            # when
            $newPoolName = 'NewPool32698'
            New-CaccaIISWebApp $testSiteName $appName -AppPoolName $newPoolName -Force -EA Stop -AppPoolConfig {
                $_.ManagedRuntimeVersion = 'v1.1'
            }

            # then
            $app = (Get-IISSite $testSiteName).Applications[$appName]
            $app.ApplicationPoolName | Should -Be $newPoolName
            $pool = Get-IISAppPool $newPoolName
            $pool.ManagedRuntimeVersion | Should -Be 'v1.1'
            Get-IISAppPool $appPoolName | Should -BeNullOrEmpty
        }
    }
    
    Context 'AppPool already assigned to another site' {
        
        BeforeAll {
            # given
            $appPoolName = 'AnotherSiteAppPool345457'
            New-CaccaIISWebsite 'AnotherSite' "$TestDrive\AnotherSite" -Port 1589 -AppPoolName $appPoolName
        }
        
        AfterAll {
            Remove-CaccaIISWebsite 'AnotherSite'
        }
        
        It 'Should throw' {
            # when, then
            { New-CaccaIISWebApp $testSiteName MyApp -AppPoolName $appPoolName -EA Stop } | Should Throw
        }
    }

    
    Context '-WhatIf' {
        BeforeAll {
            # given
            $appName = '/MyApp/Child9'
            $appPoolName = 'NonSharedPool26'

            # when
            New-CaccaIISWebApp $testSiteName $appName -AppPoolName $appPoolName -AppPoolConfig {
                # this will fail this config block were to be called
                Set-CaccaIISAppPoolUser -Commit:$false
            } -WhatIf
        }

        It 'Should NOT have created child app' {
            # then
            $site = Get-IISSite $testSiteName
            $site.Applications[$appName] | Should -BeNullOrEmpty
        }

        It 'Should NOT have created file path' {
            # then
            $expectedPhysicalPath = "$sitePath$($appName.Replace('/', '\'))"
            $expectedPhysicalPath | Should -Not -Exist
        }

        It 'Should NOT have created new pool' {
            # then
            Get-IISAppPool $appPoolName | Should -BeNullOrEmpty
        }
    }
    
    Context 'Application instance returned' {
        BeforeAll {
            # given
            $appName = '/MyApp/Child9'
            $appPoolName = 'NonSharedPool26'

            # when
            $app = New-CaccaIISWebApp $testSiteName $appName
        }
    
        AfterAll {
            Remove-CaccaIISWebApp $testSiteName $appName
        }

        It 'Should a single non-null instance' {
            # then
            ($app | measure).Count | Should -Be 1
            $app | Should -Not -BeNullOrEmpty
        }

        It 'Should be of correct type' {
            # then
            $app.GetType() | Should -Be Microsoft.Web.Administration.Application
        }

        It 'Should be the same reference returned by ServerManager' {
            # then
            $app | Should -BeExactly (Get-IISSite $testSiteName).Applications[$appName]
        }

        It 'Should be writable' {
            # when
            Start-IISCommitDelay
            $app.EnabledProtocols = 'https'
            Stop-IISCommitDelay
            
            # then
            Reset-IISServerManager -Confirm:$false
            (Get-IISSite $testSiteName).Applications[$appName].EnabledProtocols | Should -Be 'https'
        }
    }
}