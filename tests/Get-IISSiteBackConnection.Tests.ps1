$modulePath = Resolve-Path "$PSScriptRoot\..\*\*.psd1"
$moduleName = Split-Path (Split-Path $modulePath) -Leaf

Get-Module $moduleName -All | Remove-Module
Import-Module $modulePath

InModuleScope $moduleName {

    . "$PSScriptRoot\Compare-ObjectProperties.ps1"
    
    $testSiteName = 'DeleteMeSite'
    $test2SiteName = 'DeleteMeSite2'

    Describe 'Get-IISSiteBackConnection' {
        Context 'One Website' {
            
            BeforeAll {
                # given
                New-CaccaIISWebsite $testSiteName $TestDrive -HostName myhostname -Force
            }
    
            AfterAll {
                Remove-CaccaIISWebsite $testSiteName
            }
    
            Context 'site has one back connection' {
    
                BeforeAll {
                    # given
                    Mock Get-TecBoxBackConnectionHostNames { return 'myhostname' }
                }
    
                It 'Should return back connection entry' {
                    
                    # when
                    $entries = Get-CaccaIISSiteBackConnection -Name $testSiteName
                    
                    # then
                    $expected = [PsCustomObject]@{
                        Hostname  = 'myhostname'
                        SiteName  = $testSiteName
                        IsShared  = $false
                    }
                    ($entries | Measure-Object).Count | Should -Be 1
                    Compare-ObjectProperties $entries $expected | Should -Be $null
                }
            }
    
            Context 'no back connection' {
                
                BeforeAll {
                    # given
                    Mock Get-TecBoxBackConnectionHostNames { }
                }
    
                It 'Should NOT return any entries' {
                    
                    # when
                    $entries = Get-CaccaIISSiteBackConnection -Name $testSiteName
                    
                    # then
                    ($entries | Measure-Object).Count | Should -Be 0
                }
            }
    
            Context 'site has multiple back connections' {
                
                BeforeAll {
    
                    # given...
                    
                    New-IISSiteBinding $testSiteName '*:8080:myotherhostname' -Protocol http
    
                    Mock Get-TecBoxBackConnectionHostNames {
                        'myhostname'
                        'myotherhostname'
                    }
                }
    
                AfterAll {
                    Remove-IISSiteBinding $testSiteName '*:8080:myotherhostname' -Protocol http -Confirm:$false
                }
    
                It 'Should return each back connection entry' {
                    
                    # when
                    $entries = Get-CaccaIISSiteBackConnection -Name $testSiteName
                    
                    # then
                    $expected = @([PsCustomObject]@{
                            Hostname  = 'myhostname'
                            SiteName  = $testSiteName
                            IsShared  = $false
                        }, [PsCustomObject]@{
                            Hostname  = 'myotherhostname'
                            SiteName  = $testSiteName
                            IsShared  = $false
                        })
                    ($entries | Measure-Object).Count | Should -Be 2
                    Compare-ObjectProperties $entries[0] $expected[0] | Should -Be $null
                    Compare-ObjectProperties $entries[1] $expected[1] | Should -Be $null
                }
            }
        }
    
        Context 'multiple sites' {
    
            BeforeAll {
                # given
                New-CaccaIISWebsite $testSiteName "$TestDrive\site1" -HostName myhostname
                New-CaccaIISWebsite $test2SiteName "$TestDrive\site2" -HostName othersite
            }
    
            AfterAll {
                Remove-CaccaIISWebsite $testSiteName
                Remove-CaccaIISWebsite $test2SiteName
            }
    
            Context 'each site has one back connection' {
                BeforeAll {
                    # given
                    Mock Get-TecBoxBackConnectionHostNames {
                        'myhostname'
                        'othersite'
                    }
                }
    
                It 'Should return back connection entry for each site' {
                    
                    # when
                    $entries = Get-CaccaIISSiteBackConnection
                    
                    # then
                    $expected = @([PsCustomObject]@{
                            Hostname  = 'myhostname'
                            SiteName  = $testSiteName
                            IsShared  = $false
                        }, [PsCustomObject]@{
                            Hostname  = 'othersite'
                            SiteName  = $test2SiteName
                            IsShared  = $false
                        })
                    ($entries | Measure-Object).Count | Should -Be 2
                    Compare-ObjectProperties $entries[0] $expected[0] | Should -Be $null
                    Compare-ObjectProperties $entries[1] $expected[1] | Should -Be $null
                }
            }
    
            Context 'only one site has a back connection' {
                BeforeAll {
                    # given
                    Mock Get-TecBoxBackConnectionHostNames {
                        'othersite'
                    }
                }
    
                It 'Should return back connection entry for one site' {
                    
                    # when
                    $entries = Get-CaccaIISSiteBackConnection
                    
                    # then
                    $expected = [PsCustomObject]@{
                        Hostname  = 'othersite'
                        SiteName  = $test2SiteName
                        IsShared  = $false
                    }
                    ($entries | Measure-Object).Count | Should -Be 1
                    Compare-ObjectProperties $entries $expected | Should -Be $null
                }
            }
    
            Context 'each site shares multiple back connections' {
                BeforeAll {
                    # given...
    
                    Mock Get-TecBoxBackConnectionHostNames {
                        'myhostname'
                        'othersite'
                    }
    
                    New-IISSiteBinding $testSiteName '*:8080:othersite' -Protocol http
                    New-IISSiteBinding $test2SiteName '*:8081:myhostname' -Protocol http
                }
    
                AfterAll {
                    Remove-IISSiteBinding $testSiteName '*:8080:othersite' -Protocol http -Confirm:$false
                    Remove-IISSiteBinding $test2SiteName '*:8081:myhostname' -Protocol http -Confirm:$false
                }
    
                It 'Should return host file entry' {
                    
                    # when
                    $entries = Get-CaccaIISSiteBackConnection
                    
                    # then
                    $expected = @([PsCustomObject]@{
                            Hostname  = 'myhostname'
                            SiteName  = $testSiteName
                            IsShared  = $true
                        }, [PsCustomObject]@{
                            Hostname  = 'othersite'
                            SiteName  = $testSiteName
                            IsShared  = $true
                        }, [PsCustomObject]@{
                            Hostname  = 'othersite'
                            SiteName  = $test2SiteName
                            IsShared  = $true
                        }, [PsCustomObject]@{
                            Hostname  = 'myhostname'
                            SiteName  = $test2SiteName
                            IsShared  = $true
                        })
                    ($entries | Measure-Object).Count | Should -Be 4
                    Compare-ObjectProperties $entries[0] $expected[0] | Should -Be $null
                    Compare-ObjectProperties $entries[1] $expected[1] | Should -Be $null
                    Compare-ObjectProperties $entries[2] $expected[2] | Should -Be $null
                    Compare-ObjectProperties $entries[3] $expected[3] | Should -Be $null
                }
            }
        }
    }
}