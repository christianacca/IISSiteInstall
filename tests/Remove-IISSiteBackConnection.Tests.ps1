$moduleName = $env:BHProjectName
Get-Module $moduleName -All | Remove-Module
Import-Module ($global:SUTPath)


InModuleScope $moduleName {
    Describe 'Remove-IISSiteBackConnection' {
        
        BeforeEach {
            Mock Remove-TecBoxBackConnectionHostNames
        }

        Context 'One Website, 1 back connection' {
        
            It 'Should remove' {
                # given
                $entry = [PsCustomObject]@{
                    Hostname  = 'myhostname'
                    SiteName  = 'DeleteMeSite'
                    IsShared  = $false
                }
        
                # when
                $entry | Remove-CaccaIISSiteBackConnection
                    
                # then
                Assert-MockCalled Remove-TecBoxBackConnectionHostNames -Times 1 -ExclusiveFilter {$Hostnames -eq 'myhostname'}
            }
        }
        
        Context 'One Website, 2 back connections' {
                
            It 'Should remove' {
                # given
                $entry1 = [PsCustomObject]@{
                    Hostname  = 'myhostname'
                    SiteName  = 'DeleteMeSite'
                    IsShared  = $false
                }
                $entry2 = [PsCustomObject]@{
                    Hostname  = 'othername'
                    SiteName  = 'DeleteMeSite'
                    IsShared  = $false
                }

                # when
                Remove-CaccaIISSiteBackConnection $entry1, $entry2
                                
                # then
                Assert-MockCalled Remove-TecBoxBackConnectionHostNames -Times 1 -ParameterFilter {$Hostnames -eq @('myhostname')}
                Assert-MockCalled Remove-TecBoxBackConnectionHostNames -Times 1 -ParameterFilter {$Hostnames -eq @('othername')}
            }
        }
        
        Context 'One entry shared' {
            
            Context 'No -Force' {
            
                It 'Should throw' {
                        
                    # given
                    $entry = [PsCustomObject]@{
                        Hostname  = 'myhostname'
                        SiteName  = 'DeleteMeSite'
                        IsShared  = $true
                    }
            
                    # when
                    {$entry | Remove-CaccaIISSiteBackConnection -EA Stop} | Should Throw
                        
                    # then
                    Assert-MockCalled Remove-TecBoxBackConnectionHostNames -Times 0
                }
            }
        
            Context '-Force' {
            
                It 'Should remove entry' {
                        
                    # given
                    $entry = [PsCustomObject]@{
                        Hostname  = 'myhostname'
                        SiteName  = 'DeleteMeSite'
                        IsShared  = $true
                    }
            
                    # when
                    & {$entry | Remove-CaccaIISSiteBackConnection -Force -EA Stop; $true} | Should -Be $true
                        
                    # then
                    Assert-MockCalled Remove-TecBoxBackConnectionHostNames -Times 1 -ExclusiveFilter {$Hostnames -eq 'myhostname'}
                }
            }
        }
    }
}
