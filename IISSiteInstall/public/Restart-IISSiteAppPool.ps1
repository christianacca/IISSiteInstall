function Restart-IISSiteAppPool
{
    <#
    .SYNOPSIS
    Recycles the App pool(s) associated with every application of a Website
    
    .DESCRIPTION
    Recycles the App pool(s) associated with every application of a Website
    
    .PARAMETER Name
    Name of an IIS Website

    .PARAMETER Force
    Restart the pool even if it's assigned to more than one Site

    .PARAMETER MaximumWait
    The maximum time in seconds to wait on the old w3p to stop before relinquishing 
    control back to the powershell host.
    
    If not supplied, wait time is determined by taking the maximum configured 
    Shutdown Time Limit for all the pools supplied.
    
    .PARAMETER Wait
    Wait for the old w3p process servicing the app pool to stop?

    .EXAMPLE
    Restart-CaccaIISSiteAppPool Series5 -Wait
    Write-Information 'Done recycling pools'

    Description
    -----------
    Recycles the AppPool(s) assigned to Series5 website and it's child applications.
    Waits for the old w3p process servicing the pools to stop before writing the
    message 'Done recycling pools'
    
    .NOTES
    Exception thrown when:
    * Application Pool is assigned to multiple sites and -Force is NOT supplied
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Name,
        [switch] $Force,
        [int] $MaximumWait,
        [switch] $Wait
    )
    
    begin
    {
        Set-StrictMode -Version 'Latest'
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        $siteInfos = Get-IISSiteHierarchyInfo
    }
    
    process
    {
        try
        {
            $siteInfo = $siteInfos | Where-Object Site_Name -eq $Name
            if ($null -eq $siteInfo) {
                throw "Cannot recycle app pool(s) for site '$Name'; site does not exist"
            }

            $appPoolNames = $siteInfo | Where-Object AppPool_Name | Select-Object -Exp AppPool_Name -Unique

            if ($null -eq $appPoolNames) {
                Write-Warning "Cannot recycle app pool(s) for site '$Name'; site is not associated with any app pool"
            }


            $otherSiteNames = $siteInfos |
                Where-Object { $_.Site_Name -ne $Name -and $_.AppPool_Name -in $appPoolNames } |
                Select-Object -Exp Site_Name -Unique
            if ($otherSiteNames -and !$Force) {
                throw "Cannot recycle app pool(s) for site '$Name'; pool assigned to other sites ('$otherSiteNames') and -Force was not supplied"
            }

            $appPoolNames | ForEach-Object {
                $poolName = $_
                Write-Information "Recycle app pool '$poolName' for site '$Name'"
                if ($PSCmdlet.ShouldProcess($poolName, 'Recycle App pool')) {
                    Restart-IISAppPool $poolName -Wait:$Wait -MaximumWait $MaximumWait
                }
            }
        }
        catch
        {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}