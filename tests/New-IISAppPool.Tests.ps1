$modulePath = Resolve-Path "$PSScriptRoot\..\*\*.psd1"
$moduleName = Split-Path (Split-Path $modulePath) -Leaf

Get-Module $moduleName -All | Remove-Module
Import-Module $modulePath

$testSiteName = 'DeleteMeSite'
$tempAppPool = 'TestAppPool'

Describe 'New-IISAppPool' {

    Context 'App pool does not already exist' {
        BeforeEach {
            $testLocalUser = 'PesterTestUser'
            $domainQualifiedTestLocalUser = "$($env:COMPUTERNAME)\$testLocalUser"
            Get-IISAppPool $tempAppPool -WA SilentlyContinue | Remove-CaccaIISAppPool
        }
    
        AfterEach {
            Get-IISAppPool $tempAppPool | Remove-CaccaIISAppPool
            Get-LocalUser $testLocalUser -EA SilentlyContinue | Remove-LocalUser
        }
    
        It "Can create with sensible defaults" {
    
            # when
            New-CaccaIISAppPool $tempAppPool
    
            # then
            [Microsoft.Web.Administration.ApplicationPool] $pool = Get-IISAppPool $tempAppPool
            $pool.Enable32BitAppOnWin64 | Should -Be $true
            $pool.Name | Should -Be $tempAppPool
        }
    
        It "Can override defaults in config script block" {
            
            # when
            New-CaccaIISAppPool $tempAppPool -Config {
                $_.Enable32BitAppOnWin64 = $false
            }
            
            # then
            (Get-IISAppPool $tempAppPool).Enable32BitAppOnWin64 | Should -Be $false
        }
    
        It "Can create with specific user account" {
            # given
            $pswd = ConvertTo-SecureString '(pe$ter4powershell)' -AsPlainText -Force
            $creds = [PsCredential]::new($domainQualifiedTestLocalUser, $pswd)
            New-LocalUser $testLocalUser -Password $pswd
    
            # when
            New-CaccaIISAppPool $tempAppPool -Config {
                $_ | Set-CaccaIISAppPoolUser $creds -Commit:$false
            }
            
            # then
            Get-IISAppPool $tempAppPool | Get-CaccaIISAppPoolUsername | Should -Be $domainQualifiedTestLocalUser
        }

        It "Can create with explicitly with ApplicationPoolIdentity" {    
            # when
            New-CaccaIISAppPool $tempAppPool -Config {
                $_ | Set-CaccaIISAppPoolUser -IdentityType ApplicationPoolIdentity -Commit:$false
            }
            
            # then
            Get-IISAppPool $tempAppPool | Get-CaccaIISAppPoolUsername | Should -Be "IIS AppPool\$tempAppPool"
        }

        It "Can create with explicitly with NetworkService" {    
            # when
            New-CaccaIISAppPool $tempAppPool -Config {
                $_ | Set-CaccaIISAppPoolUser -IdentityType NetworkService -Commit:$false
            }
            
            # then
            Get-IISAppPool $tempAppPool | Get-CaccaIISAppPoolUsername | Should -Be 'NT AUTHORITY\NETWORK SERVICE'
        }
        
        It "Can create with explicitly with LocalSystem" {    
            # when
            New-CaccaIISAppPool $tempAppPool -Config {
                $_ | Set-CaccaIISAppPoolUser -IdentityType LocalSystem -Commit:$false
            }
            
            # then
            Get-IISAppPool $tempAppPool | Get-CaccaIISAppPoolUsername | Should -Be 'NT AUTHORITY\SYSTEM'
        }
        
        It "Can create with explicitly with LocalService" {    
            # when
            New-CaccaIISAppPool $tempAppPool -Config {
                $_ | Set-CaccaIISAppPoolUser -IdentityType LocalService -Commit:$false
            }
            
            # then
            Get-IISAppPool $tempAppPool | Get-CaccaIISAppPoolUsername | Should -Be 'NT AUTHORITY\LOCAL SERVICE'
        }
    }

    Context 'App pool already exists' {

        BeforeEach {
            New-CaccaIISWebsite $testSiteName $TestDrive -AppPoolName $tempAppPool -Force -AppPoolConfig {
                $_.Enable32BitAppOnWin64 = $false
            }
        }

        AfterEach {
            Remove-CaccaIISWebsite $testSiteName -WA SilentlyContinue -Confirm:$false
        }

        It 'Should throw' {
            {New-CaccaIISAppPool $tempAppPool -EA Stop} | Should Throw
        }

        It '-Force should replace pool' {
            # when
            New-CaccaIISAppPool $tempAppPool -Force -Config {
                $_.Enable32BitAppOnWin64 = $true
            }
            
            # then
            (Get-IISAppPool $tempAppPool).Enable32BitAppOnWin64 | Should -Be $true
        }

        It 'Replaced pool should still be associated with existing site' {
            # when
            New-CaccaIISAppPool $tempAppPool -Force -Config {
                $_.Enable32BitAppOnWin64 = $true
            }
            
            # then
            [Microsoft.Web.Administration.Site] $site = Get-IISSite $testSiteName
            $site.Applications["/"].ApplicationPoolName | Should -Be $tempAppPool
        }

        It '-WhatIf should make no modifications' {
            # when
            New-CaccaIISAppPool $tempAppPool -Force -WhatIf -Config {
                $_.Enable32BitAppOnWin64 = $true
            }
            
            # then
            (Get-IISAppPool $tempAppPool).Enable32BitAppOnWin64 | Should -Be $false
        }
    }
}