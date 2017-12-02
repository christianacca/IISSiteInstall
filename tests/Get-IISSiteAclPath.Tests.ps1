$modulePath = Resolve-Path "$PSScriptRoot\..\*\*.psd1"
$moduleName = Split-Path (Split-Path $modulePath) -Leaf

Get-Module $moduleName -All | Remove-Module
Import-Module $modulePath

. "$PSScriptRoot\Compare-ObjectProperties.ps1"

$testSiteName = 'DeleteMeSite'
$test2SiteName = 'DeleteMeSite2'
$testAppPoolName = "$testSiteName-AppPool"
$test2AppPoolName = "$test2SiteName-AppPool"
$testAppPoolUsername = "IIS AppPool\$testAppPoolName"
$test2AppPoolUsername = "IIS AppPool\$test2AppPoolName"

Describe 'Get-IISSiteAclPath' {

    BeforeAll {
        $tempAspNetPathCount = Get-CaccaTempAspNetFilesPaths | measure | select -Exp Count
    }

    Context 'Site only' {
        BeforeAll {
            New-CaccaIISWebsite $testSiteName $TestDrive -Force
        }

        AfterAll {
            Remove-CaccaIISWebsite $testSiteName -Confirm:$false
        }

        It 'Should include physical path of site' {
            # when
            $paths = Get-CaccaIISSiteAclPath $testSiteName | select -First 1

            # then
            $expected = [PsCustomObject]@{
                SiteName          = $testSiteName
                Path              = $TestDrive.ToString()
                IdentityReference = $testAppPoolUsername
                IsShared          = $false
            }
            Compare-ObjectProperties $paths $expected | Should -Be $null
        }

        It 'Should include physical path of ASP.Net temp folder' {
            # when
            $paths = Get-CaccaIISSiteAclPath $testSiteName | select -Exp Path -Skip 1
            
            # then
            $expected = Get-CaccaTempAspNetFilesPaths
            $paths | Should -Be $expected
        }
    }

    Context 'Site with no-direct AppPool permission' {
        BeforeAll {
            New-CaccaIISWebsite $testSiteName $TestDrive -Force

            # remove AppPoolIdentity user permissions from site path
            $acl = (Get-Item $TestDrive).GetAccessControl('Access')
            $acl.Access | 
                Where-Object IdentityReference -eq "IIS AppPool\$testAppPoolName" |
                ForEach-Object { $acl.RemoveAccessRuleAll($_) }
            Set-Acl -Path $TestDrive -AclObject $acl
        }

        AfterAll {
            Remove-CaccaIISWebsite $testSiteName -Confirm:$false
        }

        It 'Should NOT include physical path of site' {
            # when
            $paths = Get-CaccaIISSiteAclPath $testSiteName | select -Exp Path
            
            # then
            $paths | Should -Not -BeIn @($TestDrive.ToString())
        }
    }

    Context 'Site + 2 child apps' {
        BeforeAll {
            # given
            $childPath = "$TestDrive\MyApp1"
            $child2Path = "$TestDrive\MyApp2"
            New-CaccaIISWebsite $testSiteName $TestDrive -Force
            New-CaccaIISWebApp $testSiteName MyApp1 $childPath
            New-CaccaIISWebApp $testSiteName MyApp2 $child2Path
        }

        AfterAll {
            Remove-CaccaIISWebsite $testSiteName -Confirm:$false
        }

        It 'Should include physical path of site' {
            # when
            $paths = Get-CaccaIISSiteAclPath $testSiteName | select -First 1
            
            # then
            $expected = [PsCustomObject]@{
                SiteName          = $testSiteName
                Path              = $TestDrive.ToString()
                IdentityReference = $testAppPoolUsername
                IsShared          = $false
            }
            Compare-ObjectProperties $paths $expected | Should -Be $null
        }

        It 'Should include physical path of child apps' {
            # when
            $paths = Get-CaccaIISSiteAclPath $testSiteName | select -Skip 1 -First 2
            
            # then
            $expected = @(
                [PsCustomObject]@{
                    SiteName          = $testSiteName
                    Path              = $childPath
                    IdentityReference = $testAppPoolUsername
                    IsShared          = $false
                },
                [PsCustomObject]@{
                    SiteName          = $testSiteName
                    Path              = $child2Path
                    IdentityReference = $testAppPoolUsername
                    IsShared          = $false
                }
            )
            ($paths | Measure-Object).Count | Should -Be 2
            Compare-ObjectProperties $paths[0] $expected[0] | Should -Be $null
            Compare-ObjectProperties $paths[1] $expected[1] | Should -Be $null
        }

        Context '+ sub-folders' {

            BeforeAll {
                # given
                $subFolder = Join-Path $childPath 'SubPath1'
                $unsecuredSubFolder = Join-Path $childPath 'SubPath1\SubSubPath2'
                New-Item $subFolder -ItemType Directory
                New-Item $unsecuredSubFolder -ItemType Directory
                icacls ("$subFolder") /grant:r ("$testAppPoolUsername" + ':(OI)(CI)R') | Out-Null
            }

            Context '-Recurse' {
                BeforeAll {
                    # when
                    $paths = Get-CaccaIISSiteAclPath $testSiteName -Recurse
                }

                It 'Should include paths to secured subfolders' {
                    # then
                    ($paths | ? Path -eq $subFolder | measure).Count | Should -Be 1
                }
    
                It 'Should NOT include paths to unsecured subfolders' {
                    # then
                    ($paths | ? Path -eq $unsecuredSubFolder | measure).Count | Should -Be 0
                }
            }

            Context 'No -Recurse' {
                BeforeAll {
                    # when
                    $paths = Get-CaccaIISSiteAclPath $testSiteName
                }

                It 'Should NOT include paths to secured subfolders' {
                    # then
                    ($paths | ? Path -eq $subFolder | measure).Count | Should -Be 0
                }
            }
        }

        Context '+ specific files' {

            BeforeAll {
                # given
                New-Item "$childPath\SubPath" -ItemType Directory
                $unsecuredFilePath = (New-Item "$childPath\NotAllowed.exe" -Value 'source code' -Force).FullName
                $securedFilePath = (New-Item "$childPath\SomeProgram.exe" -Value 'source code' -Force).FullName
                $securedFile2Path = (New-Item "$childPath\SubPath\OtherProgram.exe" -Value 'source code' -Force).FullName
                icacls ("$securedFilePath") /grant:r ("$testAppPoolUsername" + ':(RX)') | Out-Null
                icacls ("$securedFile2Path") /grant:r ("$testAppPoolUsername" + ':(RX)') | Out-Null
            }
            
            Context '-Recurse' {

                BeforeAll {
                    # when
                    $paths = Get-CaccaIISSiteAclPath $testSiteName -Recurse
                }
                
                It 'Should include paths to secured files' {
                    # then
                    ($paths | ? Path -eq $securedFilePath | measure).Count | Should -Be 1
                    ($paths | ? Path -eq $securedFile2Path | measure).Count | Should -Be 1
                }
                
                It 'Should NOT include paths to unsecured subfolders' {
                    # then
                    ($paths | ? Path -eq $unsecuredFilePath | measure).Count | Should -Be 0
                }   
            }

            Context 'No -Recurse' {
                
                BeforeAll {
                    # when
                    $paths = Get-CaccaIISSiteAclPath $testSiteName
                }
                
                It 'Should NOT include paths to secured files' {
                    # then
                    ($paths | ? Path -eq $securedFilePath | measure).Count | Should -Be 0
                    ($paths | ? Path -eq $securedFile2Path | measure).Count | Should -Be 0
                }
            }
        }
    }

    Context 'Site + 2 child apps with different AppPool identities' {
        
        BeforeAll {
            # given
            $childPath = "$TestDrive\MyApp1"
            $child2Path = "$TestDrive\MyApp2"
            New-CaccaIISWebsite $testSiteName $TestDrive -Force
            New-CaccaIISWebApp $testSiteName MyApp1 $childPath -AppPoolName 'AnotherPool'
            New-CaccaIISWebApp $testSiteName MyApp2 $child2Path
        
            # when
            $paths = Get-CaccaIISSiteAclPath $testSiteName
        }

        AfterAll {
            Remove-CaccaIISWebsite $testSiteName -Confirm:$false
        }
        
        It 'Should include paths for both AppPool identities' {
            # then
            ($paths | ? IdentityReference -eq $testAppPoolUsername | measure).Count | Should -Be ($tempAspNetPathCount + 2)
            ($paths | ? IdentityReference -eq 'IIS AppPool\AnotherPool' | measure).Count | Should -Be ($tempAspNetPathCount + 1)
        }
    }

    Context '2 sites with overlapping paths and shared AppPool identities' {

        BeforeAll {
            # given...

            # note: we're needing to "manually" setup this condition as 'New-CaccaIISWebsite' would otherwise
            #       prevent it
            New-CaccaIISAppPool 'temp-pool'

            $site = New-CaccaIISWebsite $testSiteName $TestDrive -Force -AppPoolName $testAppPoolName -Port 3333

            Start-IISCommitDelay
            $site.Applications['/'].ApplicationPoolName = 'temp-pool'
            Stop-IISCommitDelay

            New-CaccaIISWebsite $test2SiteName "$TestDrive\Site2" -Force -AppPoolName $testAppPoolName

            Start-IISCommitDelay
            $site = Get-IISSite $testSiteName
            $site.Applications['/'].ApplicationPoolName = $testAppPoolName
            Stop-IISCommitDelay
        }

        AfterAll {
            Remove-CaccaIISWebsite $test2SiteName -Confirm:$false
            Remove-CaccaIISWebsite $testSiteName -Confirm:$false
            Remove-CaccaIISAppPool 'temp-pool'
        }

        Context 'No Name filter' {

            BeforeAll {
                # when
                $paths = Get-CaccaIISSiteAclPath
            }

            It 'Should include paths for all sites' {

                # then
                $site1Path = @{
                    SiteName          = $testSiteName
                    IdentityReference = $testAppPoolUsername
                }
                $site2Path = @{
                    SiteName          = $test2SiteName
                    IdentityReference = $testAppPoolUsername
                }
                $expected = @(
                    $site1Path + @{ IsShared = $false; Path = $TestDrive }
                    Get-CaccaTempAspNetFilesPaths | % { $site1Path + @{ IsShared = $true; Path = $_ } }
                    $site2Path + @{ IsShared = $false; Path = "$TestDrive\Site2" }
                    Get-CaccaTempAspNetFilesPaths | % { $site2Path + @{ IsShared = $true; Path = $_ } }
                ) | % { [PsCustomObject] $_ }

                ($paths | measure).Count | Should -Be ($expected.Count)
                for ($i = 0; $i -lt $expected.Count; $i++) {
                    Compare-ObjectProperties ($paths[$i]) ($expected[$i]) | Should -Be $null
                }
            }
        }

        Context 'No Name filter, -Recurse' {
            
            BeforeAll {
                # when
                $paths = Get-CaccaIISSiteAclPath $testSiteName -Recurse
            }
            
            It 'Overlapping paths should not be returned in recursive results' {
                # then
                $site1Path = @{
                    SiteName          = $testSiteName
                    IdentityReference = $testAppPoolUsername
                }
                $site2Path = @{
                    SiteName          = $test2SiteName
                    IdentityReference = $testAppPoolUsername
                }
                $expected = @(
                    $site1Path + @{ IsShared = $false; Path = $TestDrive }
                    Get-CaccaTempAspNetFilesPaths | % { $site1Path + @{ IsShared = $true; Path = $_ } }
                ) | % { [PsCustomObject] $_ }

                ($paths | Where Path -eq "$TestDrive\Site2" | measure).Count | Should -Be 0
            }
        }
    }
}