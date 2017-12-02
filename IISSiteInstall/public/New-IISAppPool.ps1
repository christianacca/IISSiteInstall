#Requires -RunAsAdministrator

function New-IISAppPool
{
    <#
    .SYNOPSIS
    Creates a new IIS application pool
    
    .DESCRIPTION
    Creates a new IIS application pool
    
    .PARAMETER Name
    The name of the pool
    
    .PARAMETER Config
    A script block that will receive the instance of the pool being created
    
    .PARAMETER Force
    Overwrite any existing pool?
    
    .PARAMETER Commit
    Save changes to IIS immediately? Defaults to true
    
    .EXAMPLE
    New-CaccaIISAppPool MyNewPool

    Description
    -----------
    Create pool using the defaults configured for all application pools.
    The exception to the defaults is 'Enable32BitAppOnWin64' is set to $true (best practice)

    .EXAMPLE
    New-CaccaIISAppPool MyNewPool -Config {
        $_.Enable32BitAppOnWin64 = $false
    }

    Description
    -----------
    Configures the pool being created with custom settings

    .EXAMPLE
    New-CaccaIISAppPool $tempAppPool -Config {
        $_ | Set-CaccaIISAppPoolUser -IdentityType NetworkService -Commit:$false
    }

    Description
    -----------
    Create the pool with an identity assigned to the Network Service built-in account

    .EXAMPLE
    $pswd = ConvertTo-SecureString '(mypassword)' -AsPlainText -Force
    $creds = [PsCredential]::new("$($env:COMPUTERNAME)\MyLocalUser", $pswd)

    New-CaccaIISAppPool $tempAppPool -Config {
        $_ | Set-CaccaIISAppPoolUser $creds -Commit:$false
    }

    Description
    -----------
    Create the pool with an identity assigned to a specific user account

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(ValueFromPipelineByPropertyName)]
        [scriptblock] $Config,

        [switch] $Force,

        [switch] $Commit
    )
    
    begin
    {
        Set-StrictMode -Version 'Latest'
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        if (!$PSBoundParameters.ContainsKey('Commit'))
        {
            $Commit = $true
        }
    }
    
    process
    {
        try
        {
            
            if ($null -eq $Config)
            {
                $Config = {}
            }

            [Microsoft.Web.Administration.ServerManager] $manager = Get-IISServerManager

            $existingPool = $manager.ApplicationPools[$Name]

            if (!$Force -and $existingPool)
            {
                throw "App pool '$Name' already exists. Supply -Force to overwrite"
            }

            if ($Commit)
            {
                Start-IISCommitDelay
            }
            try
            {
                if ($existingPool -and $PSCmdlet.ShouldProcess($Name, 'Remove App pool'))
                {
                    # note: not using Remove-IISAppPool as do NOT want to remove file permissions
                    $manager.ApplicationPools.Remove($existingPool)
                }

                if ($PSCmdlet.ShouldProcess($Name, 'Create App pool'))
                {
                    [Microsoft.Web.Administration.ApplicationPool] $pool = $manager.ApplicationPools.Add($Name)

                    # todo: do NOT set this when it's detected that OS is 64bit onlys
                    $pool.Enable32BitAppOnWin64 = $true # this IS the recommended default even for 64bit servers

                    $pool | ForEach-Object $Config
                }
                if ($Commit)
                {
                    Stop-IISCommitDelay
                }                 
            }
            catch
            {
                if ($Commit)
                {
                    Stop-IISCommitDelay -Commit:$false
                }
                throw
            }
            finally
            {
                if ($Commit)
                {
                    # make sure subsequent scripts will not fail because the ServerManger is now readonly
                    Reset-IISServerManager -Confirm:$false
                }
            }

            Get-IISAppPool $Name
        }
        catch
        {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}