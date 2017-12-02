function Get-IISSiteAclPath {
    <#
    .SYNOPSIS
    Return the file/folder paths where the identity of the AppPool(s) used by the
    IIS site has been assigned one or more file/folder permission
    
    .DESCRIPTION
    Return the file/folder paths where the identity of the AppPool(s) used by the
    IIS site has been assigned one or more file/folder permission.

    The physical path of the website along with any child applications will be inspected.

    Optionally, supply the name of a IIS Website to return just those paths for a single site.

    Optionally, supply -Recurse to search all nested paths under the physical paths inspected.

    Items in the output have a 'IsShared' property. A path is considered shared if it has a
    permission assigned to an Identity that is used on more than one IIS website.

    This 'IsShared' property will typically be used to determine which file permissions can
    be safely removed when an IIS Website is removed
    
    .PARAMETER Name
    Name of an IIS Website
    
    .PARAMETER Recurse
    Search subfolders

    .EXAMPLE
    Get-CaccaIISSiteAclPath Series5 -Recurse

	SiteName Path                                                                    IdentityReference           IsShared
	-------- ----                                                                    -----------------           --------
	Series5  C:\inetpub\sites\Series5                                                IIS AppPool\Series5-AppPool    False
	Series5  C:\Git\Series5\src\Ram.Series5.Spa                                      IIS AppPool\Series5-AppPool    False
	Series5  C:\Git\Series5\src\Ram.Series5.WinLogin                                 IIS AppPool\Series5-AppPool    False
	Series5  C:\Git\Series5\src\Ram.Series5.Spa\App_Data                             IIS AppPool\Series5-AppPool    False
	Series5  C:\Git\Series5\src\Ram.Series5.WinLogin\App_Data                        IIS AppPool\Series5-AppPool    False
	Series5  C:\Windows\Microsoft.NET\Framework64\v2.0.50727\Temporary ASP.NET Files IIS AppPool\Series5-AppPool    False
	Series5  C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files IIS AppPool\Series5-AppPool    False
    
    .NOTES
    Currently, Virtual Directories will not be inspected
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [switch] $Recurse
    )
    
    begin {
        Set-StrictMode -Version 'Latest'
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        $allSiteInfos = @()
        $allSiteInfos += Get-IISSiteAclPathHelper
    }
    
    process {
        try {
            if (![string]::IsNullOrWhiteSpace($Name)) {
                $Name = $Name.Trim()
            }


            $siteInfos = if ([string]::IsNullOrWhiteSpace($Name)) {
                $allSiteInfos
            }
            else {
                $allSiteInfos | Where-Object SiteName -eq $Name
            }

            $siteNames = @()
            $siteNames += $siteInfos | Select-Object -Exp SiteName -Unique

            foreach ($siteName in $siteNames) {
                $siteAclPaths = Get-IISSiteAclPathHelper $siteName -Recurse:$Recurse
                $otherSiteAclPaths = $allSiteInfos | Where-Object SiteName -ne $siteName

                Write-Debug "Acl Paths: $siteAclPaths"
                
                $siteAclPaths | ForEach-Object {
                    $path = $_.Path
                    $identityReference = $_.IdentityReference
                    $isShared = ($otherSiteAclPaths | 
                        Where-Object { $_.Path -eq $path -and $_.IdentityReference -eq $identityReference } |
                        Measure-Object).Count -ne 0
                    $_ | Select-Object -Property *, @{ n='IsShared'; e={$isShared}}
                }                
            }

        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}