param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Name
)
if (-not(Get-PSRepository -Name $Name -EA SilentlyContinue))
{
    Write-Output "  Registering custom PS Repository '$Name'"    
    $repo = @{
        Name                  = $Name
        SourceLocation        = "https://www.myget.org/F/$Name/api/v2"
        ScriptSourceLocation  = "https://www.myget.org/F/$Name/api/v2/"
        PublishLocation       = "https://www.myget.org/F/$Name/api/v2/package"
        ScriptPublishLocation = "https://www.myget.org/F/$Name/api/v2/package/"
        InstallationPolicy    = 'Trusted'
    }
    Register-PSRepository @repo
}