$modulePath = Resolve-Path "$PSScriptRoot\..\*\*.psd1"
$moduleName = Split-Path (Split-Path $modulePath) -Leaf

Get-Module $moduleName -All | Remove-Module
Import-Module $modulePath

. "$PSScriptRoot\Compare-ObjectProperties.ps1"

$testSiteName = 'DeleteMeSite'
$test2SiteName = 'DeleteMeSite2'
$tempAppPool = "$testSiteName-AppPool"


Describe 'Get-IISSiteHierarchyInfo' {

    Context 'Site only' {

        BeforeAll {
            New-CaccaIISWebsite $testSiteName $TestDrive -Force
        }

        AfterAll {
            Remove-CaccaIISWebsite $testSiteName -Confirm:$false
        }

        It 'Should return site app pool' {
            # when
            $info = Get-CaccaIISSiteHierarchyInfo $testSiteName

            # then
            $pool = Get-IISAppPool $tempAppPool

            $expected = [PsCustomObject]@{
                Site_Name            = $testSiteName
                App_Path             = '/'
                App_PhysicalPath     = $TestDrive
                AppPool_Name         = $tempAppPool
                AppPool_IdentityType = $pool.ProcessModel.IdentityType
                AppPool_Username     = "IIS AppPool\$tempAppPool"
            }
            ($info | Measure-Object).Count | Should -Be 1
            Compare-ObjectProperties $info $expected | Should -Be $null
        }
    }

    
    Context 'Site missing AppPool' {
        
        BeforeAll {
            New-CaccaIISWebsite $testSiteName $TestDrive -Force
            Remove-CaccaIISAppPool $tempAppPool -Force
        }
        
        AfterAll {
            Remove-CaccaIISWebsite $testSiteName -Confirm:$false
        }
        
        It 'Should return site only info' {
            # when
            $info = Get-CaccaIISSiteHierarchyInfo $testSiteName
        
            # then
            $expected = [PsCustomObject]@{
                Site_Name            = $testSiteName
                App_Path             = '/'
                App_PhysicalPath     = $TestDrive
                AppPool_Name         = $null
                AppPool_IdentityType = $null
                AppPool_Username     = $null
            }
            ($info | Measure-Object).Count | Should -Be 1
            Compare-ObjectProperties $info $expected | Should -Be $null
        }
    }

    Context 'All sites' {
        
        BeforeAll {
            New-CaccaIISWebsite $testSiteName $TestDrive -Force
            New-CaccaIISWebsite $test2SiteName $TestDrive -Force -Port 1111
        }
        
        AfterAll {
            Remove-CaccaIISWebsite $testSiteName -Confirm:$false
            Remove-CaccaIISWebsite $test2SiteName -Confirm:$false
        }
        
        It 'Should return info for all sites' {
            # when
            $info = Get-CaccaIISSiteHierarchyInfo
        
            # then
            ($info | Measure-Object).Count | Should -BeGreaterThan 1
            $info | ? Site_Name -eq $testSiteName | Should -Not -BeNullOrEmpty
            $info | ? Site_Name -eq $test2SiteName | Should -Not -BeNullOrEmpty
        }
    }

    Context "Site and child app" {

        BeforeAll {
            # given
            New-CaccaIISWebsite $testSiteName $TestDrive -Force
            New-CaccaIISWebApp $testSiteName MyApp1
        }

        AfterAll {
            Remove-CaccaIISWebsite $testSiteName -Confirm:$false
        }

        It 'Should return site and child app pool' {
            # when
            $info = Get-CaccaIISSiteHierarchyInfo $testSiteName
            
            # then
            $pool = Get-IISAppPool $tempAppPool
            $expected = @(
                [PsCustomObject]@{
                    Site_Name            = $testSiteName
                    App_Path             = '/'
                    App_PhysicalPath     = $TestDrive
                    AppPool_Name         = $tempAppPool
                    AppPool_IdentityType = $pool.ProcessModel.IdentityType
                    AppPool_Username     = "IIS AppPool\$tempAppPool"
                },
                [PsCustomObject]@{
                    Site_Name            = $testSiteName
                    App_Path             = '/MyApp1'
                    App_PhysicalPath     = (Join-Path $TestDrive 'MyApp1')
                    AppPool_Name         = $tempAppPool
                    AppPool_IdentityType = $pool.ProcessModel.IdentityType
                    AppPool_Username     = "IIS AppPool\$tempAppPool"
                }
            )
            ($info | Measure-Object).Count | Should -Be 2
            Compare-ObjectProperties $info[0] $expected[0] | Should -Be $null
            Compare-ObjectProperties $info[1] $expected[1] | Should -Be $null
        }
    }
}