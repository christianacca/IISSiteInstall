$script:sitesToRemove = @()

function Cleanup 
{
    $script:sitesToRemove | Remove-CaccaIISWebsite -WA Ignore -Confirm:$false
    $script:sitesToRemove = @()
}

function CreateTestSite 
{
    param(
        [string] $Name,
        [string] $BindingInformation = '*:7070:',
        [string] $AppPoolName
    )

    $sitePath = Join-Path $TestDrive $Name
    New-Item $sitePath -ItemType Directory | Out-Null
    New-IISSite $Name $sitePath -BindingInformation $BindingInformation | Out-Null

    if ($AppPoolName) {
        Start-IISCommitDelay
        New-IISAppPool $AppPoolName -Commit:$false
        [Microsoft.Web.Administration.Site] $site = Get-IISSite $Name
        $site.Applications["/"].ApplicationPoolName = $AppPoolName
        Stop-IISCommitDelay
    }

    $script:sitesToRemove += $Name
}

function New-SiteName
{
     'PS-{0}' -f (Get-Random -Minimum 100 -Maximum 1000000).ToString()
}