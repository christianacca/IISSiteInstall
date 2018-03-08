$script:sitesToRemove = @()

function Cleanup 
{
    $script:sitesToRemove | Remove-IISSite -WA Ignore -Confirm:$false
    $script:sitesToRemove = @()
}

function CreateTestSite 
{
    param(
        [string] $Name,
        [string] $BindingInformation = '*:7070:'
    )

    $sitePath = Join-Path $TestDrive $Name
    New-Item $sitePath -ItemType Directory | Out-Null
    New-IISSite $Name $sitePath -BindingInformation $BindingInformation | Out-Null

    $script:sitesToRemove += $Name
}

function New-SiteName
{
    (New-Guid).ToString().Substring(0, 5)
}