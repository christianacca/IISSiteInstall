$moduleName = $env:BHProjectName
Unload-SUT
Import-Module ($global:SUTPath)

InModuleScope $moduleName {

    . "$PSScriptRoot\Compare-ObjectProperties.ps1"
    
    $testSiteName = 'DeleteMeSite'
    $test2SiteName = 'DeleteMeSite2'

    Describe 'Get-IISWebsiteHostsFileEntry' -Tags Build {

        AfterAll {
            Unload-SUT
        }
        
        Context 'One Website' {
            
            BeforeAll {
                # given
                New-CaccaIISWebsite $testSiteName $TestDrive -HostName myhostname -Force
            }
    
            AfterAll {
                Remove-CaccaIISWebsite $testSiteName
            }
    
            Context 'site has one hostname in hosts file' {
    
                BeforeAll {
                    # given
                    Mock Get-TecBoxHostnames {
                        [PsCustomObject]@{ Hostname = 'myhostname'; IpAddress = '127.0.0.1' } 
                    }
                }
    
                It 'Should return host file entry' {
                    
                    # when
                    $entries = Get-CaccaIISSiteHostsFileEntry -Name $testSiteName
                    
                    # then
                    $expected = [PsCustomObject]@{
                        Hostname  = 'myhostname'
                        IpAddress = '127.0.0.1'
                        SiteName  = $testSiteName
                        IsShared  = $false
                    }
                    ($entries | Measure-Object).Count | Should -Be 1
                    Compare-ObjectProperties $entries $expected | Should -Be $null
                }
            }
    
            Context 'hostname NOT in hosts file' {
                
                BeforeAll {
                    # given
                    Mock Get-TecBoxHostnames { }
                }
    
                It 'Should NOT return any entries' {
                    
                    # when
                    $entries = Get-CaccaIISSiteHostsFileEntry -Name $testSiteName
                    
                    # then
                    ($entries | Measure-Object).Count | Should -Be 0
                }
            }
    
            Context 'site has multiple hostnames in hosts file' {
                
                BeforeAll {
    
                    # given...
                    
                    New-IISSiteBinding $testSiteName '*:8080:myotherhostname' -Protocol http
    
                    Mock Get-TecBoxHostnames {
                        [PsCustomObject]@{ Hostname = 'myhostname'; IpAddress = '127.0.0.1' } 
                        [PsCustomObject]@{ Hostname = 'myotherhostname'; IpAddress = '127.0.0.1' } 
                    }
                }
    
                AfterAll {
                    Remove-IISSiteBinding $testSiteName '*:8080:myotherhostname' -Protocol http -Confirm:$false
                }
    
                It 'Should return each hosts file entry' {
                    
                    # when
                    $entries = Get-CaccaIISSiteHostsFileEntry -Name $testSiteName
                    
                    # then
                    $expected = @([PsCustomObject]@{
                            Hostname  = 'myhostname'
                            IpAddress = '127.0.0.1'
                            SiteName  = $testSiteName
                            IsShared  = $false
                        }, [PsCustomObject]@{
                            Hostname  = 'myotherhostname'
                            IpAddress = '127.0.0.1'
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
    
            Context 'each site has one hostname in hosts file' {
                BeforeAll {
                    # given
                    Mock Get-TecBoxHostnames {
                        [PsCustomObject]@{ Hostname = 'myhostname'; IpAddress = '127.0.0.1' } 
                        [PsCustomObject]@{ Hostname = 'othersite'; IpAddress = '127.0.0.1' } 
                    }
                }
    
                It 'Should return host file entry' {
                    
                    # when
                    $entries = Get-CaccaIISSiteHostsFileEntry
                    
                    # then
                    $expected = @([PsCustomObject]@{
                            Hostname  = 'myhostname'
                            IpAddress = '127.0.0.1'
                            SiteName  = $testSiteName
                            IsShared  = $false
                        }, [PsCustomObject]@{
                            Hostname  = 'othersite'
                            IpAddress = '127.0.0.1'
                            SiteName  = $test2SiteName
                            IsShared  = $false
                        })
                    ($entries | Measure-Object).Count | Should -Be 2
                    Compare-ObjectProperties $entries[0] $expected[0] | Should -Be $null
                    Compare-ObjectProperties $entries[1] $expected[1] | Should -Be $null
                }
            }
    
            Context 'only one site has a hostname in hosts file' {
                BeforeAll {
                    # given
                    Mock Get-TecBoxHostnames {
                        [PsCustomObject]@{ Hostname = 'othersite'; IpAddress = '127.0.0.1' } 
                    }
                }
    
                It 'Should return host file entry' {
                    
                    # when
                    $entries = Get-CaccaIISSiteHostsFileEntry
                    
                    # then
                    $expected = [PsCustomObject]@{
                        Hostname  = 'othersite'
                        IpAddress = '127.0.0.1'
                        SiteName  = $test2SiteName
                        IsShared  = $false
                    }
                    ($entries | Measure-Object).Count | Should -Be 1
                    Compare-ObjectProperties $entries $expected | Should -Be $null
                }
            }
    
            Context 'each site shares multiple hostnames in hosts file' {
                BeforeAll {
                    # given...
    
                    Mock Get-TecBoxHostnames {
                        [PsCustomObject]@{ Hostname = 'myhostname'; IpAddress = '127.0.0.1' } 
                        [PsCustomObject]@{ Hostname = 'othersite'; IpAddress = '127.0.0.1' } 
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
                    $entries = Get-CaccaIISSiteHostsFileEntry
                    
                    # then
                    $expected = @([PsCustomObject]@{
                            Hostname  = 'myhostname'
                            IpAddress = '127.0.0.1'
                            SiteName  = $testSiteName
                            IsShared  = $true
                        }, [PsCustomObject]@{
                            Hostname  = 'othersite'
                            IpAddress = '127.0.0.1'
                            SiteName  = $testSiteName
                            IsShared  = $true
                        }, [PsCustomObject]@{
                            Hostname  = 'othersite'
                            IpAddress = '127.0.0.1'
                            SiteName  = $test2SiteName
                            IsShared  = $true
                        }, [PsCustomObject]@{
                            Hostname  = 'myhostname'
                            IpAddress = '127.0.0.1'
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