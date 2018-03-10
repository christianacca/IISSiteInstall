Describe 'Add-IISSitePort' -Tag Build {

    . "$PSScriptRoot\TestHelpers.ps1"

    function GetBindings 
    {
        param([string]$SiteName)

        $list = Get-IISSiteBinding $SiteName
        foreach($item in $list) {
            $item
        }
    }

    BeforeAll {
        Unload-SUT
        Import-Module ($global:SUTPath)
    }

    AfterAll {
        Unload-SUT
    }

    Context 'One existing binding' {

        BeforeAll {

            # given
            $siteName = New-SiteName
            CreateTestSite -Name $siteName -BindingInformation '*:7070:'

            # when
            Add-CaccaIISSitePort $siteName 7080
        }

        AfterAll {
            Cleanup
        }

        It 'Should add new endpoint with new port' {
            GetBindings $siteName | Select -Exp BindingInformation | Should -Be '*:7070:', '*:7080:'
        }
    }

    Context 'One existing binding (with host and IP)' {

        BeforeAll {

            # given
            $siteName = New-SiteName
            CreateTestSite -Name $siteName -BindingInformation "172.30.32.1:7070:$siteName"

            # when
            Add-CaccaIISSitePort $siteName 7080
        }

        AfterAll {
            Cleanup
        }

        It 'Should add new endpoint with new port' {
            $bindingInfo = GetBindings $siteName| Select -Exp BindingInformation
            $bindingInfo | Should -Be "172.30.32.1:7070:$siteName", "172.30.32.1:7080:$siteName"
        }
    }
    
    Context 'Port already bound' {
        BeforeAll {

            # given
            $siteName = New-SiteName
            CreateTestSite -Name $siteName -BindingInformation "*:7070:"

            # when
            Add-CaccaIISSitePort $siteName 7070
        }

        AfterAll {
            Cleanup
        }

        It 'Should ignore addition' {
            GetBindings $siteName | Select -Exp BindingInformation | Should -Be '*:7070:'
        }
    }
    
    Context 'Multiple existing bindings' {
       
        BeforeAll {

            # given
            $siteName = New-SiteName
            CreateTestSite -Name $siteName -BindingInformation "172.30.32.1:8080:$siteName"
            New-IISSiteBinding $siteName "172.30.32.1:8090:$siteName"
            New-IISSiteBinding $siteName "172.30.32.1:8060:blah"

            # when
            Add-CaccaIISSitePort $siteName 7070
        }

        AfterAll {
            Cleanup
        }

        It 'Should add new EndPoint for each existing IP/host name' {
            $bindingInfo = GetBindings $siteName| Select -Exp BindingInformation
            $expected = @(
                "172.30.32.1:8080:$siteName", "172.30.32.1:8090:$siteName", "172.30.32.1:8060:blah",
                "172.30.32.1:7070:$siteName", "172.30.32.1:7070:blah"
            )
            $bindingInfo | Should -Be $expected
        }
    }
    
    Context 'Some existing bindings with port' {
       
        BeforeAll {

            # given
            $siteName = New-SiteName
            CreateTestSite -Name $siteName -BindingInformation "172.30.32.1:8080:$siteName"
            New-IISSiteBinding $siteName "172.30.32.1:7070:$siteName"
            New-IISSiteBinding $siteName "172.30.32.1:8060:blah"

            # when
            Add-CaccaIISSitePort $siteName 7070
        }

        AfterAll {
            Cleanup
        }

        It 'Should add new missing EndPoint' {
            $bindingInfo = GetBindings $siteName| Select -Exp BindingInformation
            $expected = @(
                "172.30.32.1:8080:$siteName", "172.30.32.1:7070:$siteName", "172.30.32.1:8060:blah",
                "172.30.32.1:7070:blah"
            )
            $bindingInfo | Should -Be $expected
        }
    }
}
