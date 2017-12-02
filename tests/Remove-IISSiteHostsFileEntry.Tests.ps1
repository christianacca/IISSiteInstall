$modulePath = Resolve-Path "$PSScriptRoot\..\*\*.psd1"
$moduleName = Split-Path (Split-Path $modulePath) -Leaf

Get-Module $moduleName -All | Remove-Module
Import-Module $modulePath


InModuleScope $moduleName {
    Describe 'Remove-IISSiteHostsFileEntry' {
        
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
