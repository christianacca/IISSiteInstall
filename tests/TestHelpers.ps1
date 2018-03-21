$script:sitesToRemove = @()

function Cleanup 
{
    $script:sitesToRemove | Remove-CaccaIISWebsite -WA Ignore -Confirm:$false
    $script:sitesToRemove = @()
}

function CreateTestSite 
{
    param(
        [string] $Name = (New-SiteName),
        [string] $BindingInformation = '*:7070:',
        [string] $AppPoolName,
        [switch] $Start
    )

    $sitePath = Join-Path $TestDrive $Name
    New-Item $sitePath -ItemType Directory -Force -Confirm:$false | Out-Null
    New-IISSite $Name $sitePath -BindingInformation $BindingInformation | Out-Null
    Unlock-CaccaIISAnonymousAuth -Location $Name
    Copy-Item "$PSScriptRoot\TestData\default.htm" $sitePath
    Copy-Item "$PSScriptRoot\TestData\web.config" $sitePath


    if ($AppPoolName) {
        Start-IISCommitDelay
        New-CaccaIISAppPool $AppPoolName -Commit:$false -Config {
            $_ | Set-CaccaIISAppPoolUser -IdentityType LocalSystem -Commit:$false
        }
        [Microsoft.Web.Administration.Site] $site = Get-IISSite $Name
        $site.Applications["/"].ApplicationPoolName = $AppPoolName
        Stop-IISCommitDelay
    }

    $script:sitesToRemove += $Name

    if ($Start) {
        $port = $BindingInformation.Replace('*:', '').Replace(':', '')
        Invoke-WebRequest "http://localhost:$port/default.htm" -UseBasicParsing -EA Stop
    }
}

function New-AppPoolName
{
     'PS-{0}-AppPool' -f (Get-Random -Minimum 100 -Maximum 1000000).ToString()
}

function New-SiteName
{
     'PS-{0}' -f (Get-Random -Minimum 100 -Maximum 1000000).ToString()
}