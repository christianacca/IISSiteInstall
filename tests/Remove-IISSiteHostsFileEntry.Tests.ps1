$moduleName = $env:BHProjectName
Unload-SUT
Import-Module ($global:SUTPath)

InModuleScope $moduleName {
    Describe 'Remove-IISSiteHostsFileEntry' -Tags Build {

        AfterAll {
            Unload-SUT
        }
        
        BeforeEach {
            Mock Remove-TecBoxHostnames
        }

        Context 'One Website, 1 hostname' {
        
            It 'Should remove' {
                # given
                $entry = [PsCustomObject]@{
                    Hostname  = 'myhostname'
                    IpAddress = '127.0.0.1'
                    SiteName  = 'DeleteMeSite'
                    IsShared  = $false
                }
        
                # when
                $entry | Remove-CaccaIISSiteHostsFileEntry
                    
                # then
                Assert-MockCalled Remove-TecBoxHostnames -Times 1 -ExclusiveFilter {$Hostnames -eq 'myhostname'}
            }
        }
        
        Context 'One Website, 2 hostname' {
                
            It 'Should remove' {
                # given
                $entry1 = [PsCustomObject]@{
                    Hostname  = 'myhostname'
                    IpAddress = '127.0.0.1'
                    SiteName  = 'DeleteMeSite'
                    IsShared  = $false
                }
                $entry2 = [PsCustomObject]@{
                    Hostname  = 'othername'
                    IpAddress = '127.0.0.1'
                    SiteName  = 'DeleteMeSite'
                    IsShared  = $false
                }

                # when
                Remove-CaccaIISSiteHostsFileEntry $entry1, $entry2
                                
                # then
                Assert-MockCalled Remove-TecBoxHostnames -Times 1 -ParameterFilter {$Hostnames -eq @('myhostname')}
                Assert-MockCalled Remove-TecBoxHostnames -Times 1 -ParameterFilter {$Hostnames -eq @('othername')}
            }
        }
        
        Context 'One entry shared' {
            
            Context 'No -Force' {
            
                It 'Should throw' {
                        
                    # given
                    $entry = [PsCustomObject]@{
                        Hostname  = 'myhostname'
                        IpAddress = '127.0.0.1'
                        SiteName  = 'DeleteMeSite'
                        IsShared  = $true
                    }
            
                    # when
                    {$entry | Remove-CaccaIISSiteHostsFileEntry -EA Stop} | Should Throw
                        
                    # then
                    Assert-MockCalled Remove-TecBoxHostnames -Times 0
                }
            }
        
            Context '-Force' {
            
                It 'Should remove entry' {
                        
                    # given
                    $entry = [PsCustomObject]@{
                        Hostname  = 'myhostname'
                        IpAddress = '127.0.0.1'
                        SiteName  = 'DeleteMeSite'
                        IsShared  = $true
                    }
            
                    # when
                    & {$entry | Remove-CaccaIISSiteHostsFileEntry -Force -EA Stop; $true} | Should -Be $true
                        
                    # then
                    Assert-MockCalled Remove-TecBoxHostnames -Times 1 -ExclusiveFilter {$Hostnames -eq 'myhostname'}
                }
            }
        }
    }
}
