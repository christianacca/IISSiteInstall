$modulePath = Resolve-Path "$PSScriptRoot\..\*\*.psd1"
$moduleName = Split-Path (Split-Path $modulePath) -Leaf

Get-Module $moduleName -All | Remove-Module
Import-Module $modulePath

$testSiteName = 'DeleteMeSite'
$testAppPoolName = "$testSiteName-AppPool"
$testAppPoolUsername = "IIS AppPool\$testAppPoolName"
$sitePath = "C:\inetpub\sites\$testSiteName"


Describe 'New-IISWebsite' {

    function Cleanup {
        Reset-IISServerManager -Confirm:$false
        $siteToDelete = Get-IISSite $testSiteName -WA SilentlyContinue
        if ($siteToDelete) {
            Remove-CaccaIISWebsite $testSiteName -Confirm:$false
            Remove-Item ($siteToDelete.Applications['/'].VirtualDirectories['/'].PhysicalPath) -Recurse -Confirm:$false
        }
        if (Test-Path $sitePath) {
            Remove-Item $sitePath -Recurse -Confirm:$false
        }
        Get-LocalUser 'PesterTestUser-*' | Remove-LocalUser
    }

    BeforeEach {
        $tempSitePath = "$TestDrive\$testSiteName"
        Cleanup
    }

    AfterEach {
        Cleanup
    }

    It "With defaults" {
        # when
        New-CaccaIISWebsite $testSiteName

        # then
        [Microsoft.Web.Administration.Site] $site = Get-IISSite $testSiteName
        $site | Should -Not -BeNullOrEmpty

        $binding = $site.Bindings[0]
        $binding.Protocol | Should -Be 'http'
        $binding.EndPoint.Port | Should -Be 80

        $appPool = Get-IISAppPool $testAppPoolName
        $appPool | Should -Not -BeNullOrEmpty
        $appPool.Name | Should -Be $testAppPoolName
        $appPool.Enable32BitAppOnWin64 | Should -Be $true
        $appPool | Get-CaccaIISAppPoolUsername | Should -Be $testAppPoolUsername

        $site.Applications['/'].ApplicationPoolName | Should -Be $testAppPoolName
        $site.Applications["/"].VirtualDirectories["/"].PhysicalPath | Should -Be $sitePath

        $checkAccess = {
            $identities = (Get-Acl $_).Access.IdentityReference
            $identities | ? { $_.Value -eq $testAppPoolUsername } | Should -Not -BeNullOrEmpty
        }

        $sitePath | % $checkAccess
        Get-CaccaTempAspNetFilesPaths | % $checkAccess
    }

    It "-Path" {
        # when
        New-CaccaIISWebsite $testSiteName $tempSitePath

        # then
        [Microsoft.Web.Administration.Site] $site = Get-IISSite $testSiteName
        $site | Should -Not -BeNullOrEmpty
        $site.Applications['/'].VirtualDirectories['/'].PhysicalPath | Should -Be $tempSitePath
        $identities = (Get-Acl $tempSitePath).Access.IdentityReference
        $identities | ? Value -eq $testAppPoolUsername | Should -Not -BeNullOrEmpty
    }

    It "-Config" {
        # given
        [Microsoft.Web.Administration.Site] $siteArg = $null
        $Config = {
            $siteArg = $_
            New-IISSiteBinding $_.Name ':8082:' http
        }

        # when
        $site = New-CaccaIISWebsite $testSiteName -Config $Config

        # then
        $siteArg | Should -Not -Be $null
        $siteArg.Name | Should -Be ($site.Name)
        $site.Bindings.Count | Should -Be 2
    }

    It "-HostName" {
        # when
        New-CaccaIISWebsite $testSiteName -HostName 'local-site'

        # then
        [Microsoft.Web.Administration.Site] $site = Get-IISSite $testSiteName
        $site | Should -Not -BeNullOrEmpty
        $site.Bindings[0].Host | Should -Be 'local-site'
    }

    It "-AppPoolName" {
        # when
        New-CaccaIISWebsite $testSiteName -AppPoolName 'MyAppPool'

        # then
        [Microsoft.Web.Administration.Site] $site = Get-IISSite $testSiteName
        $site | Should -Not -BeNullOrEmpty
        $site.Applications["/"].ApplicationPoolName | Should -Be 'MyAppPool'
    }

    It "-AppPoolConfig used to set AppPool identity to specific user" {
        # given
        $testLocalUser = "PesterTestUser-$(Get-Random -Maximum 10000)"
        $domainQualifiedTestLocalUser = "$($env:COMPUTERNAME)\$testLocalUser"
        $pswd = ConvertTo-SecureString '(pe$ter4powershell)' -AsPlainText -Force
        $creds = [PsCredential]::new($domainQualifiedTestLocalUser, $pswd)
        New-LocalUser $testLocalUser -Password $pswd

        # when
        New-CaccaIISWebsite $testSiteName $tempSitePath -EA Stop -AppPoolConfig {
            $_ | Set-CaccaIISAppPoolUser $creds -Commit:$false
        }
        
        # then
        $appPool = Get-IISAppPool $testAppPoolName
        $appPool | Should -Not -BeNullOrEmpty
        $appPool | Get-CaccaIISAppPoolUsername | Should -Be $domainQualifiedTestLocalUser
        & {
            $tempSitePath
            Get-CaccaTempAspNetFilesPaths
        } | % {
            $identities = (Get-Acl $_).Access.IdentityReference
            $identities | ? { $_.Value -eq $domainQualifiedTestLocalUser } | Should -Not -BeNullOrEmpty
        }        
    }

    It "-AppPoolConfig" {
        # given
        [Microsoft.Web.Administration.ApplicationPool]$pool = $null
        $appPoolConfig = {
            $pool = $_
            $_.ManagedRuntimeVersion = 'v2.0'
        }

        # when
        New-CaccaIISWebsite $testSiteName -AppPoolConfig $appPoolConfig

        # then
        $pool | Should -Not -BeNullOrEmpty
        (Get-IISAppPool $testAppPoolName).ManagedRuntimeVersion | Should -Be 'v2.0'
    }

    It "-SiteShellOnly" {
        # when
        New-CaccaIISWebsite $testSiteName -SiteShellOnly

        # then
        Get-IISSite $testSiteName | Should -Not -BeNullOrEmpty  
        # todo: verify that Set-CaccaIISSiteAcl called with -SiteShellOnly
    }

    It "Site returned should be modifiable" {
        # given
        $otherPath = "TestDrive:\SomeFolder"
        New-Item $otherPath -ItemType Directory

        # when
        [Microsoft.Web.Administration.Site] $site = New-CaccaIISWebsite $testSiteName

        Start-IISCommitDelay
        $site.Applications['/'].VirtualDirectories['/'].PhysicalPath = $otherPath
        Stop-IISCommitDelay

        # then
        (Get-IISSite $testSiteName).Applications.VirtualDirectories.PhysicalPath | Should -Be $otherPath
    }

    It "Pipeline property binding" {
        # given
        $siteParams = @{
            Name          = $testSiteName
            Path          = $tempSitePath
            Port          = 80
            Protocol      = 'http'
            HostName      = 'local-site'
            Config        = {}
            ModifyPaths   = @()
            ExecutePaths  = @()
            SiteShellOnly = $true
            AppPoolName   = 'MyApp3'
        }

        # when
        New-CaccaIISWebsite @siteParams

        # then
        Get-IISSite $testSiteName | Should -Not -BeNullOrEmpty
    }

    It "-WhatIf should not modify anything" {
        # when
        New-CaccaIISWebsite $testSiteName $tempSitePath -AppPoolName 'MyAppPool'  -AppPoolConfig {
            # this will fail this config block were to be called
            Set-CaccaIISAppPoolUser -Commit:$false
        } -WhatIf

        # then
        Get-IISSite $testSiteName -WA SilentlyContinue | Should -BeNullOrEmpty
        Get-IISAppPool 'MyAppPool' -WA SilentlyContinue | Should -BeNullOrEmpty
        Test-Path $tempSitePath | Should -Be $false
    }

    It "-WhatIf should not modify anything (site path exists)" {
        # given
        New-Item $sitePath -ItemType Directory -EA Ignore

        # when
        New-CaccaIISWebsite $testSiteName $sitePath -AppPoolName 'MyAppPool' -WhatIf

        # then
        Get-IISSite $testSiteName -WA SilentlyContinue | Should -BeNullOrEmpty
        Get-IISAppPool 'MyAppPool' -WA SilentlyContinue | Should -BeNullOrEmpty
        Test-Path $tempSitePath | Should -Be $false
    }

    Context 'AppPool already assigned to another site' {

        BeforeEach {
            # given
            New-CaccaIISWebsite 'AnotherSite' "$TestDrive\AnotherSite" -Port 692 -AppPoolName $testAppPoolName
        }

        AfterEach {
            Remove-CaccaIISWebsite 'AnotherSite'
        }

        It 'Should throw' {
            # when, then
            { New-CaccaIISWebsite $testSiteName "$TestDrive\$testSiteName" -EA Stop } | Should Throw
        }
    }
}

InModuleScope $moduleName {

    Describe 'New-IISWebsite' -Tag Unit {

        Context '-AddHostToBackConnections' {

            BeforeAll {
                # given
                $testSiteName = 'DeleteMeSite'
                $tempSitePath = "$TestDrive\$testSiteName"

                Mock Add-TecBoxBackConnectionHostNames
            }

            AfterEach {
                Remove-CaccaIISWebsite $testSiteName -Confirm:$false
            }

            It 'Should add -Hostname to backconnections' {
                # when
                New-CaccaIISWebsite $testSiteName $tempSitePath -Hostname deleteme -AddHostToBackConnections

                # then
                Assert-MockCalled Add-TecBoxBackConnectionHostNames -Exactly 1 -Scope It -ExclusiveFilter {$HostNames -eq 'deleteme'}
            }

            It 'Should add host names from extra binding to backconnections' {
                # when
                New-CaccaIISWebsite $testSiteName $tempSitePath -Hostname deleteme -AddHostToBackConnections -Config {
                    New-IISSiteBinding $_.Name ':8082:deleteme2' http
                }
        
                # then
                Assert-MockCalled Add-TecBoxBackConnectionHostNames -Exactly 1 -Scope It -ParameterFilter {$HostNames -eq 'deleteme'}
                Assert-MockCalled Add-TecBoxBackConnectionHostNames -Exactly 1 -Scope It -ParameterFilter {$HostNames -eq 'deleteme2'}
            }
        }
    }
}

InModuleScope $moduleName {

    Describe 'New-IISWebsite' -Tag Unit {

        Context '-HostsFileIPAddress' {

            BeforeAll {
                # given
                $testSiteName = 'DeleteMeSite'
                $tempSitePath = "$TestDrive\$testSiteName"
                Mock Add-TecBoxHostnames
                Mock Remove-TecBoxHostnames
            }

            AfterEach {
                Remove-CaccaIISWebsite $testSiteName -Confirm:$false
            }
        
            It 'Should add -Hostname to hosts file' {
                # when
                New-CaccaIISWebsite $testSiteName $tempSitePath -Hostname deleteme -HostsFileIPAddress 127.0.0.1
        
                # then
                Assert-MockCalled Add-TecBoxHostnames -Exactly 1 -Scope It `
                    -ExclusiveFilter {$Hostnames -eq 'deleteme' -and $IPAddress -eq '127.0.0.1'}
            }

            It 'Should add host names from extra binding to hosts file' {
                # when
                $site = New-CaccaIISWebsite $testSiteName $tempSitePath -Hostname deleteme -HostsFileIPAddress 127.0.0.1 -Config {
                    New-IISSiteBinding $_.Name ':8082:deleteme2' http
                }
        
                # then
                Assert-MockCalled Add-TecBoxHostnames -Exactly 1 -Scope It `
                    -ParameterFilter {$Hostnames -eq 'deleteme' -and $IPAddress -eq '127.0.0.1'}
                Assert-MockCalled Add-TecBoxHostnames -Exactly 1 -Scope It `
                    -ParameterFilter {$Hostnames -eq 'deleteme2' -and $IPAddress -eq '127.0.0.1'}
            }
        }

        Context '-HostsFileIPAddress, when hosts file binds a different IP to hostname' {
            
            BeforeAll {
                # given
                $testSiteName = 'DeleteMeSite'
                $tempSitePath = "$TestDrive\$testSiteName"
                Mock Add-TecBoxHostnames
                Mock Remove-TecBoxHostnames
                Mock Get-TecBoxHostnames { 
                    [PsCustomObject]@{ Hostname = 'testhost'; IpAddress = '127.0.0.1' } 
                    [PsCustomObject]@{ Hostname = 'deleteme'; IpAddress = '192.168.0.1' } 
                }

                New-CaccaIISWebsite AnotherSite2 $tempSitePath -Hostname testhost -HostsFileIPAddress 127.0.0.1 -Port 8081 `
                    -AppPoolName NowYouSeeMePool
                New-CaccaIISWebsite $testSiteName $tempSitePath -Hostname deleteme -HostsFileIPAddress 192.168.0.1 -Port 8090

                $errored = $false
            
                # when
                try {
                    New-CaccaIISWebsite AnotherSite2 $tempSitePath -Hostname deleteme -HostsFileIPAddress 127.0.0.1 `
                        -Force -EA Stop
                }
                catch {
                    $errored = $true
                }
            }

            AfterAll {
                Remove-CaccaIISWebsite $testSiteName -Confirm:$false
                Remove-CaccaIISWebsite AnotherSite2 -Confirm:$false
            }

            It 'Should throw' -Skip {

                # TODO

                # then
                $errored | Should -Be $true
            }
            
            It 'Should not change hostfile' -Skip {

                # TODO

                Assert-MockCalled Remove-TecBoxHostnames -Exactly 0
                Assert-MockCalled Add-TecBoxHostnames -Exactly 0 -ParameterFilter { $IpAddress -eq '127.0.0.1' }
            }
            
            It 'Should not have modified IIS' -Skip {

                # TODO

                # then
                (Get-IISSiteBinding AnotherSite2).BindingInformation | Should -Be ':8090:deleteme'
                Get-IISAppPool NowYouSeeMePool | Should -Not -BeNullOrEmpty
            }
        }
    }
}