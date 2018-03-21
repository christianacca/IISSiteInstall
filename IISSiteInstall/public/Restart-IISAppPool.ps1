function Restart-IISAppPool
{
    <#
    .SYNOPSIS
    Restart IIS App pool
    
    .DESCRIPTION
    Restart IIS App pool, optionally waiting for the old process to stop

    .PARAMETER Name
    The name of the pool to recycle
    
    .PARAMETER MaximumWait
    The maximum time in seconds to wait on the old w3p to stop before relinquishing 
    control back to the powershell host.
    
    If not supplied, wait time is determined by taking the maximum configured 
    Shutdown Time Limit for all the pools supplied.
    
    .PARAMETER Wait
    Wait for the old w3p process servicing the app pool to stop?

    .EXAMPLE
    Restart-IISAppPool 'MyAppPoolName'

    Description
    -----------
    Recycles the AppPool named MyAppPoolName. Immediately returns without waiting for the
    old w3p process servicing the pool to stop
    
    .EXAMPLE
    @('MyAppPoolName', 'MyAppPoolName2') | Restart-IISAppPool -Wait
    Write-Information 'Done recycling pools'

    Description
    -----------
    Recycles the AppPools MyAppPoolName and MyAppPoolName2. Waits for the old w3p process
    servicing the pools to stop before writing the message 'Done recycling pools'
    
    .NOTES
    Throws when:
    * The app pool supplied does not exist
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $Name,

        [int] $MaximumWait,

        [switch] $Wait
    )
    
    begin {
        Set-StrictMode -Version 'Latest'
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        if ($MaximumWait -gt 0 -and !$PSBoundParameters.ContainsKey('Wait')) {
            $Wait = $true
        }

        $appPoolNames = @()
    }

    process {
        $appPoolNames += $Name
    }

    end {
        try {

            if ($Wait) {
                # reset IIS so that we can retrieve the current ProcessId for each app pool
                Reset-IISServerManager -Confirm:$false
            }

            $appPools = $appPoolNames | Select-Object -Unique | ForEach-Object {
                $pool = Get-IISAppPool $_ -WA SilentlyContinue
                $processId = $pool | Select-Object -Exp WorkerProcesses -EA Ignore | Select-Object -Exp ProcessId
                [PsCustomObject] @{
                    Name = $_
                    Pool = $pool
                    ProcessId = $processId
                }
            }

            $missingPools = $appPools | Where-Object { $null -eq $_.Pool } | Select-Object -Exp Name -Unique
            if ($missingPools) {
                throw "Cannot recycle app pool(s); app pools '$missingPools' missing"
            }

            $waitSeconds = if ($Wait) {
                $maxShutdownWaitSeconds = ($appPools.Pool.ProcessModel.ShutdownTimeLimit | Measure-Object TotalSeconds -Maximum).Maximum
                $configuredWait = if ($maxShutdownWaitSeconds -eq 0) {
                    Write-Warning "AppPool timeout is not restricted. Consider supplying a -MaximumWait to avoid waiting indefinitely"
                    31536000 # 1 year
                } else {
                    $killWaitSeconds = 5
                    $maxShutdownWaitSeconds  + $killWaitSeconds
                }
                if ($MaximumWait -gt 0 -and $configuredWait -gt $MaximumWait) { 
                    $MaximumWait 
                } else { 
                    $configuredWait
                }
            } else {
                0
            }

            foreach ($appPool in $appPools) {
                if ($PSCmdlet.ShouldProcess($appPool.Name, 'Restart App pool')) {
                    $appPool.Pool.Recycle() | Out-Null
                }
            }

            if ($waitSeconds -gt 0 -and !$WhatIfPreference) {
                $processIds = $appPools | Select-Object -Exp ProcessId -Unique
                Write-Verbose "Waiting for app pool(s) to shutdown"
                Write-Verbose "Max wait time of $waitSeconds"
                $timeout = (Get-Date).AddSeconds($waitSeconds)
                while ($timeout -gt (Get-Date) -and @(Get-Process -Id $processIds -EA Ignore).Count -gt 0) {
                    Start-Sleep -Seconds 2
                }
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}