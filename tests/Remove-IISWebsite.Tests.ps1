$modulePath = Resolve-Path "$PSScriptRoot\..\*\*.psd1"
$moduleName = Split-Path (Split-Path $modulePath) -Leaf

Get-Module $moduleName -All | Remove-Module
Import-Module $modulePath

$testSiteName = 'DeleteMeSite'
$test2SiteName = 'DeleteMeSite2'
$testAppPool = "$testSiteName-AppPool"
$testAppPoolUsername = "IIS AppPool\$testSiteName-AppPool"
$test2AppPool = "$test2SiteName-AppPool"
$test2AppPoolUsername = "IIS AppPool\$test2SiteName-AppPool"
$childAppPool = "MyApp-AppPool"


Describe 'Remove-IISWebsite' {

    function GetAppPoolPermission {
        param(
            [string] $Path,
            [string] $Username
        )
        (Get-Item $Path).GetAccessControl('Access').Access |
            Where-Object { $_.IsInherited -eq $false -and $_.IdentityReference -eq $Username }
    }

    function Cleanup {
        Reset-IISServerManager -Confirm:$false
        Start-IISCommitDelay
        Remove-IISSite $testSiteName -EA Ignore -Confirm:$false -WA SilentlyContinue
        Remove-IISSite $test2SiteName -EA Ignore -Confirm:$false -WA SilentlyContinue
        @($testAppPool, $test2AppPool, $childAppPool) | Remove-CaccaIISAppPool -Commit:$false -Force -EA Ignore
        Stop-IISCommitDelay
        Reset-IISServerManager -Confirm:$false
    }

    Context "Site only" {

        BeforeAll {
            Cleanup

            # given
            New-CaccaIISWebsite $testSiteName $TestDrive -AppPoolName $testAppPool

            # when
            Remove-CaccaIISWebsite $testSiteName -Confirm:$false

            Reset-IISServerManager -Confirm:$false
        }

        AfterAll {
            Cleanup
        }

        It 'Should remove site and app pool' {
            # then
            Get-IISSite $testSiteName -WA SilentlyContinue | Should -BeNullOrEmpty
            Get-IISAppPool $testAppPool -WA SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'ServerManager should be reset after delete' {
            # then
            # note: this would fail if ServerManger was NOT reset
            New-IISSite $testSiteName $TestDrive '*:2222:' -EA Stop -Passthru | Should -Not -BeNullOrEmpty
        }

        It 'Should remove App pool file permissions' {
            # then
            & {
                $TestDrive
                Get-CaccaTempAspNetFilesPaths
            } | % {
                GetAppPoolPermission $_ $testAppPoolUsername | Should -BeNullOrEmpty
            }   
        }

    }

    Context "Site only, specific user assigned as AppPool identity" {
        
        BeforeAll {
            Cleanup
        
            # given...

            $testLocalUser = "PesterTestUser-$(Get-Random -Maximum 10000)"
            $domainQualifiedTestLocalUser = "$($env:COMPUTERNAME)\$testLocalUser"
            $pswd = ConvertTo-SecureString '(pe$ter4powershell)' -AsPlainText -Force
            $creds = [PsCredential]::new($domainQualifiedTestLocalUser, $pswd)
            New-LocalUser $testLocalUser -Password $pswd

            New-CaccaIISWebsite $testSiteName $TestDrive -AppPoolName $testAppPool -AppPoolConfig {
                $_ | Set-CaccaIISAppPoolUser $creds -Commit:$false
            }
        

            # when
            Remove-CaccaIISWebsite $testSiteName -Confirm:$false
        
            Reset-IISServerManager -Confirm:$false
        }
        
        AfterAll {
            Cleanup
            Get-LocalUser 'PesterTestUser-*' | Remove-LocalUser
        }
        
        It 'Should remove site and app pool' {
            # then
            Get-IISSite $testSiteName -WA SilentlyContinue | Should -BeNullOrEmpty
            Get-IISAppPool $testAppPool -WA SilentlyContinue | Should -BeNullOrEmpty
        }
        
        It 'Should remove App pool file permissions' {
            # then
            & {
                $TestDrive
                Get-CaccaTempAspNetFilesPaths
            } | % {
                GetAppPoolPermission $_ $domainQualifiedTestLocalUser | Should -BeNullOrEmpty
            }   
        }
        
    }

    Context "Site only -WhatIf" {
        
        BeforeAll {
            Cleanup
            # given
            New-CaccaIISWebsite $testSiteName $TestDrive -AppPoolName $testAppPool
        }

        AfterAll {
            Cleanup
        }
        
        It 'Should make no modifications' {
            # when
            Remove-CaccaIISWebsite $testSiteName -WhatIf
        
            # then
            Get-IISSite $testSiteName | Should -Not -BeNullOrEmpty
            Get-IISAppPool $testAppPool | Should -Not -BeNullOrEmpty
            GetAppPoolPermission $TestDrive $testAppPoolUsername | Should -Not -BeNullOrEmpty
        }        
    }
            
    Context "Site and child app" {

        BeforeAll {
            Cleanup
            New-CaccaIISWebsite $testSiteName $TestDrive -Force
            New-CaccaIISWebApp $testSiteName MyApp1 -AppPoolName $childAppPool
        }

        AfterAll {
            Cleanup
        }

        It 'Should remove site and site and child app pool' {
            # when
            Remove-CaccaIISWebsite $testSiteName -Confirm:$false
            
            # then
            Get-IISSite $testSiteName -WA SilentlyContinue | Should -BeNullOrEmpty
            Get-IISAppPool $testAppPool -WA SilentlyContinue | Should -BeNullOrEmpty
            Get-IISAppPool $childAppPool -WA SilentlyContinue | Should -BeNullOrEmpty
        }
    }

    Context "Site and child app - shared app pool" {

        BeforeAll {
            Cleanup

            # given...

            # note: we're needing to "manually" setup this condition as 'New-CaccaIISWebsite' would otherwise
            #       prevent it

            New-CaccaIISAppPool 'temp-pool'
            
            $site = New-CaccaIISWebsite $test2SiteName "$TestDrive\Site2" -AppPoolName $test2AppPool -Port 3564

            Start-IISCommitDelay
            $site.Applications['/'].ApplicationPoolName = 'temp-pool'
            Stop-IISCommitDelay

            New-CaccaIISWebsite $testSiteName $TestDrive -AppPoolName $test2AppPool

            Start-IISCommitDelay
            $site = Get-IISSite $test2SiteName
            $site.Applications['/'].ApplicationPoolName = $test2AppPool
            Stop-IISCommitDelay

            $childPath = "$TestDrive\MyApp1"
            New-CaccaIISWebApp $testSiteName MyApp1 -AppPoolName $testAppPool


            # checking assumptions
            GetAppPoolPermission "$TestDrive\Site2" $test2AppPoolUsername | Should -Not -BeNullOrEmpty
            GetAppPoolPermission $TestDrive $test2AppPoolUsername | Should -Not -BeNullOrEmpty
            GetAppPoolPermission $childPath $testAppPoolUsername | Should -Not -BeNullOrEmpty


            # when
            Remove-CaccaIISWebsite $testSiteName -Confirm:$false
        }
                
        AfterAll {
            Cleanup
            Remove-CaccaIISAppPool 'temp-pool'
        }
        
        It 'Should remove site except share app pool' {
            # then
            Get-IISSite $testSiteName -WA SilentlyContinue | Should -BeNullOrEmpty
            Get-IISAppPool $testAppPool -WA SilentlyContinue | Should -BeNullOrEmpty
            Get-IISAppPool $test2AppPool | Should -Not -BeNullOrEmpty
        }

        It 'Should remove App pool file permissions only on non-shared folders' {
            # then
            Get-CaccaTempAspNetFilesPaths | % {
                GetAppPoolPermission $_ $test2AppPoolUsername | Should -Not -BeNullOrEmpty
            }
            GetAppPoolPermission $TestDrive $testAppPoolUsername | Should -BeNullOrEmpty
            GetAppPoolPermission "$TestDrive\Site2" $test2AppPoolUsername | Should -Not -BeNullOrEmpty
            GetAppPoolPermission $childPath $testAppPoolUsername | Should -BeNullOrEmpty
        }
    }
}
    
InModuleScope $moduleName {
    
    Describe 'Remove-IISWebsite' -Tag Unit {
    
        BeforeAll {
            # given
            $testSiteName = 'DeleteMeSite'
            $tempSitePath = "$TestDrive\$testSiteName"
            Mock Remove-TecBoxBackConnectionHostNames
            Mock Add-TecBoxBackConnectionHostNames
            Mock Get-TecBoxBackConnectionHostNames { return 'deleteme' }

            New-CaccaIISWebsite $testSiteName $tempSitePath -Hostname deleteme -AddHostToBackConnections
        }

        Context 'Host registered as back connection' {
            
            It 'Should remove' {
                # when
                Remove-CaccaIISWebsite $testSiteName -Confirm:$false
            
                # then
                Assert-MockCalled Remove-TecBoxBackConnectionHostNames -Exactly 1 -Scope It `
                    -ExclusiveFilter {$Hostnames -eq 'deleteme'}
            }
        }

        Context 'Host registered as back connection is shared with other sites' {
            
            BeforeAll {
                # given
                New-CaccaIISWebsite AnotherSite3 $tempSitePath -Hostname deleteme -Port 8095 -AddHostToBackConnections
            }

            AfterAll {
                Remove-CaccaIISWebsite AnotherSite3 -Confirm:$false
            }

            It 'Should NOT remove' {
                # when
                Remove-CaccaIISWebsite $testSiteName -Confirm:$false
            
                # then
                Assert-MockCalled Remove-TecBoxBackConnectionHostNames -Exactly 0 -Scope It
            }
        }
    }
}