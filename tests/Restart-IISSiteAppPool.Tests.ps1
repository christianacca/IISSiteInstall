
$moduleName = $env:BHProjectName
Unload-SUT
Import-Module ($global:SUTPath)

InModuleScope $moduleName {
    
    Describe 'Restart-IISSiteAppPool' -Tag Build, Unit {

        . "$PSScriptRoot\TestHelpers.ps1"
        AfterAll { Unload-SUT }

        Mock Restart-AppPool

        Context 'Site missing' {

            BeforeAll {
                Mock Get-IISSiteHierarchyInfo {
                    @()
                }
            }
       
            It 'Should throw' {
                # when, then
                { Restart-CaccaIISSiteAppPool DoesNotExist -EA Stop } | Should Throw
            }
        }
    
    
        Context 'Site with one app pool' {
    
            BeforeAll {

                # given
                $siteName = New-SiteName
                Mock Get-IISSiteHierarchyInfo {
                    [PsCustomObject] @{
                        Site_Name = $siteName
                        App_Path = '/'
                        AppPool_Name = "$siteName-AppPool"
                    }
                }

                # when
                Restart-CaccaIISSiteAppPool $siteName
            }
    
            It 'Should recycle the app pool belonging to site' {
                # then
                Assert-MockCalled Restart-AppPool -Exactly 1 `
                    -ParameterFilter { $Name -eq "$siteName-AppPool" }
            }
        }
        
        Context 'Site hierarchy with 3 app pools' {
    
            BeforeAll {

                # given
                $siteName = New-SiteName
                Mock Get-IISSiteHierarchyInfo {
                    [PsCustomObject] @{
                        Site_Name = $siteName
                        App_Path = '/'
                        AppPool_Name = $siteName
                    }
                    [PsCustomObject] @{
                        Site_Name = $siteName
                        App_Path = '/ChildApp'
                        AppPool_Name = "$siteName-ChildApp"
                    }
                    [PsCustomObject] @{
                        Site_Name = $siteName
                        App_Path = '/ChildApp2'
                        AppPool_Name = "$siteName-SharedPool"
                    }
                    [PsCustomObject] @{
                        Site_Name = $siteName
                        App_Path = '/ChildApp3'
                        AppPool_Name = "$siteName-SharedPool"
                    }
                }
            }

            It '-WhatIf should not perform recycle' {
                # when
                Restart-CaccaIISSiteAppPool $siteName -WhatIf

                # then
                Assert-MockCalled Restart-AppPool -Exactly 0
            }
    
            It 'Should recycle the app pools belonging to site and child applications' {
                # when
                Restart-CaccaIISSiteAppPool $siteName

                # then
                Assert-MockCalled Restart-AppPool -Exactly 3
            }
        }
        
        Context 'App pool shared by apps on multiple sites' {
           
            AfterAll { Cleanup }
    
            BeforeAll {

                # given
                $site1Name = New-SiteName
                $site2Name = New-SiteName
                $sharedAppPoolName = "$(New-SiteName)-shared"
                Mock Get-IISSiteHierarchyInfo {
                    [PsCustomObject] @{
                        Site_Name = $site1Name
                        App_Path = '/'
                        AppPool_Name = $site1Name
                    }
                    [PsCustomObject] @{
                        Site_Name = $site1Name
                        App_Path = '/ChildApp'
                        AppPool_Name = $sharedAppPoolName
                    }
                    [PsCustomObject] @{
                        Site_Name = $site2Name
                        App_Path = '/'
                        AppPool_Name = $site2Name
                    }
                    [PsCustomObject] @{
                        Site_Name = $site2Name
                        App_Path = '/ChildApp'
                        AppPool_Name = $sharedAppPoolName
                    }
                }
            }

            It 'Should throw when -Force not supplied' {
                # when, then
                { Restart-CaccaIISSiteAppPool $site1Name -EA Stop } | Should Throw
            }
            
            It 'Should allow recycle when -Force supplied' {
                # when
                Restart-CaccaIISSiteAppPool $site1Name -Force

                # then
                Assert-MockCalled Restart-AppPool -Exactly 2
                Assert-MockCalled Restart-AppPool -Exactly 0 `
                    -ParameterFilter { $Name -eq $site2Name }
            }
        }

    }
}