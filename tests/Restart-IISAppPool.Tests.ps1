. "$PSScriptRoot\TestHelpers.ps1"

Describe 'Restart-IISAppPool' -Tag Build {

    if ($ENV:BHBuildSystem -eq 'AppVeyor') {
        Write-Warning "Skip tests on AppVeyor as failing with 'No connection could be made because the target machine actively refused it'"
        return
    }

    function Get-AppPoolProcessId {
        param([string] $Name)
        Reset-IISServerManager -Confirm:$false
        Get-IISAppPool $Name | Select-Object -Exp WorkerProcesses -EA Ignore | Select-Object -Exp ProcessId
    }

    BeforeAll {
        Unload-SUT
        Import-Module ($global:SUTPath)
    }

    AfterAll {
        Unload-SUT
    }

    Context 'App pool missing' {
       
        It 'Should throw' {
            # when, then
            { Restart-CaccaIISAppPool DoesNotExist -EA Stop } | Should Throw
        }
    }
    
    Context 'One App Pool' {

        AfterAll { Cleanup }
       
        BeforeAll {

            # given...

            $appPoolName = New-AppPoolName
            CreateTestSite -AppPoolName $appPoolName -Start
            $appPoolProcessId = Get-AppPoolProcessId $appPoolName

            # checking assumptions
            Get-Process -Id $appPoolProcessId | Should -Not -BeNullOrEmpty
        }

        Context 'One pool name supplied' {

            BeforeAll {
                # when
                Restart-CaccaIISAppPool $appPoolName
                Start-Sleep -Seconds 5
            }

            It 'Should have stopped the w3p process' {
                # then
                try {
                    Get-Process -Id $appPoolProcessId -EA Stop | Should -BeNullOrEmpty
                }
                catch {
                    $_.ToString() | Should -Be "Cannot find a process with the process identifier $appPoolProcessId."
                }
            }
        }

        Context 'Duplicate pool names supplied' {

            It 'Should not fail' {
                # when, then
                & { @($appPoolName, $appPoolName) | Restart-CaccaIISAppPool; $true } | Should -Be $true
            }
        }
    }
    
    Context 'Multiple App Pools' {

        AfterAll { Cleanup }
       
        BeforeAll {

            # given...

            $appPoolName1 = New-AppPoolName
            CreateTestSite -BindingInformation '*:8936:' -AppPoolName $appPoolName1 -Start
            $appPoolProcessId1 = Get-AppPoolProcessId $appPoolName1
            
            $appPoolName2 = New-AppPoolName
            CreateTestSite -BindingInformation '*:8937:' -AppPoolName $appPoolName2
            $appPoolProcessId2 = Get-AppPoolProcessId $appPoolName2
            
            $appPoolName3 = New-AppPoolName
            CreateTestSite -BindingInformation '*:8938:' -AppPoolName $appPoolName3 -Start
            $appPoolProcessId3 = Get-AppPoolProcessId $appPoolName3


            # checking assumptions
            Get-Process -Id $appPoolProcessId1 | Should -Not -BeNullOrEmpty
            $appPoolProcessId2 | Should -BeNullOrEmpty
            Get-Process -Id $appPoolProcessId3 | Should -Not -BeNullOrEmpty
        }

        Context 'No -Wait -WhatIf' {
            BeforeAll {
                # when
                @($appPoolName1, $appPoolName2, $appPoolName3) | Restart-CaccaIISAppPool -WhatIf
            }

            It 'Should not recycle pool' {
                # then
                Get-Process -Id $appPoolProcessId1 | Should -Not -BeNullOrEmpty
                Get-Process -Id $appPoolProcessId3 | Should -Not -BeNullOrEmpty
            }

            It 'Should NOT start second stopped w3p process' {
                # then
                Get-AppPoolProcessId $appPoolName2 | Should -BeNullOrEmpty
            }
        }
        
        Context '-Wait -WhatIf' {
            BeforeAll {
                # when
                @($appPoolName1, $appPoolName2, $appPoolName3) | Restart-CaccaIISAppPool -Wait -WhatIf
            }

            It 'Should not recycle pool' {
                # then
                Get-Process -Id $appPoolProcessId1 | Should -Not -BeNullOrEmpty
                Get-Process -Id $appPoolProcessId3 | Should -Not -BeNullOrEmpty
            }

            It 'Should NOT start second stopped w3p process' {
                # then
                Get-AppPoolProcessId $appPoolName2 | Should -BeNullOrEmpty
            }
        }

        Context 'No -Wait' {
            
            BeforeAll {
                # when
                @($appPoolName1, $appPoolName2, $appPoolName3) | Restart-CaccaIISAppPool
                Start-Sleep -Seconds 5
            }

            It 'Should have stopped first w3p process' {
                # then
                try {
                    Get-Process -Id $appPoolProcessId1 -EA Stop | Should -BeNullOrEmpty
                }
                catch {
                    $_.ToString() | Should -Be "Cannot find a process with the process identifier $appPoolProcessId1."
                }
            }
            
            It 'Should NOT start second stopped w3p process' {
                # then
                Get-AppPoolProcessId $appPoolName2 | Should -BeNullOrEmpty
            }
            
            It 'Should have stopped third w3p process' {
                # then
                try {
                    Get-Process -Id $appPoolProcessId3 -EA Stop | Should -BeNullOrEmpty
                }
                catch {
                    $_.ToString() | Should -Be "Cannot find a process with the process identifier $appPoolProcessId3."
                }
            }
        }
        
        Context '-Wait' {

            BeforeAll {

                # given
                Reset-IISServerManager -Confirm:$false
                $appPoolProcessId1 = Get-AppPoolProcessId $appPoolName1
                $appPoolProcessId2 = Get-AppPoolProcessId $appPoolName2
                $appPoolProcessId3 = Get-AppPoolProcessId $appPoolName3

                # checking assumptions
                Get-Process -Id $appPoolProcessId1 | Should -Not -BeNullOrEmpty
                $appPoolProcessId2 | Should -BeNullOrEmpty
                Get-Process -Id $appPoolProcessId3 | Should -Not -BeNullOrEmpty


                # when
                @($appPoolName1, $appPoolName2, $appPoolName3) | Restart-CaccaIISAppPool -Wait -Verbose
            }

            Context 'pool names supplied by pipeline' {

                BeforeAll {
                    # when
                    @($appPoolName1, $appPoolName2, $appPoolName3) | Restart-CaccaIISAppPool -Wait -Verbose
                }

                It 'Should have stopped first w3p process' {
                    # then
                    try {
                        Get-Process -Id $appPoolProcessId1 -EA Stop | Should -BeNullOrEmpty
                    }
                    catch {
                        $_.ToString() | Should -Be "Cannot find a process with the process identifier $appPoolProcessId1."
                    }
                }
                
                It 'Should NOT start second stopped w3p process' {
                    # then
                    Get-AppPoolProcessId $appPoolName2 | Should -BeNullOrEmpty
                }
                
                It 'Should have stopped third w3p process' {
                    # then
                    try {
                        Get-Process -Id $appPoolProcessId3 -EA Stop | Should -BeNullOrEmpty
                    }
                    catch {
                        $_.ToString() | Should -Be "Cannot find a process with the process identifier $appPoolProcessId3."
                    }
                }
            }
            
            Context 'pool names supplied as array' {

                BeforeAll {
                    # when
                    Restart-CaccaIISAppPool $appPoolName1, $appPoolName2, $appPoolName3 -Wait -Verbose
                }

                It 'Should have stopped first w3p process' {
                    # then
                    try {
                        Get-Process -Id $appPoolProcessId1 -EA Stop | Should -BeNullOrEmpty
                    }
                    catch {
                        $_.ToString() | Should -Be "Cannot find a process with the process identifier $appPoolProcessId1."
                    }
                }
                
                It 'Should NOT start second stopped w3p process' {
                    # then
                    Get-AppPoolProcessId $appPoolName2 | Should -BeNullOrEmpty
                }
                
                It 'Should have stopped third w3p process' {
                    # then
                    try {
                        Get-Process -Id $appPoolProcessId3 -EA Stop | Should -BeNullOrEmpty
                    }
                    catch {
                        $_.ToString() | Should -Be "Cannot find a process with the process identifier $appPoolProcessId3."
                    }
                }
            }
        }
        
        Context '-MaximumWait' {

            BeforeAll {

                # given
                Reset-IISServerManager -Confirm:$false
                $appPoolProcessId1 = Get-AppPoolProcessId $appPoolName1
                $appPoolProcessId2 = Get-AppPoolProcessId $appPoolName2
                $appPoolProcessId3 = Get-AppPoolProcessId $appPoolName3

                # checking assumptions
                Get-Process -Id $appPoolProcessId1 | Should -Not -BeNullOrEmpty
                $appPoolProcessId2 | Should -BeNullOrEmpty
                Get-Process -Id $appPoolProcessId3 | Should -Not -BeNullOrEmpty


                # when
                @($appPoolName1, $appPoolName2, $appPoolName3) | Restart-CaccaIISAppPool -MaximumWait 30 -Verbose
            }

            It 'Should have stopped first w3p process' {
                # then
                try {
                    Get-Process -Id $appPoolProcessId1 -EA Stop | Should -BeNullOrEmpty
                }
                catch {
                    $_.ToString() | Should -Be "Cannot find a process with the process identifier $appPoolProcessId1."
                }
            }
            
            It 'Should NOT start second stopped w3p process' {
                # then
                Get-AppPoolProcessId $appPoolName2 | Should -BeNullOrEmpty
            }
            
            It 'Should have stopped third w3p process' {
                # then
                try {
                    Get-Process -Id $appPoolProcessId3 -EA Stop | Should -BeNullOrEmpty
                }
                catch {
                    $_.ToString() | Should -Be "Cannot find a process with the process identifier $appPoolProcessId3."
                }
            }
        }
    }
}
