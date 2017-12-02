function ConvertTo-BuiltInUsername
{
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('ApplicationPoolIdentity', 'LocalService', 'LocalSystem', 'NetworkService')]
        [string] $IdentityType,

        [Parameter(Mandatory)]
        [string] $AppPoolName
    )
    
    begin
    {
        Set-StrictMode -Version 'Latest'
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        if ($IdentityType -eq 'ApplicationPoolIdentity' -and [string]::IsNullOrWhiteSpace($AppPoolName))
        {
            throw "IdentityType of 'ApplicationPoolIdentity' requires that an -AppPoolName"
        }
    }
    
    process
    {
        try
        {

            switch ($IdentityType)
            {
                'ApplicationPoolIdentity'
                { 
                    "IIS AppPool\$AppPoolName"
                }
                'NetworkService'
                { 
                    'NT AUTHORITY\NETWORK SERVICE'
                }
                'LocalSystem'
                { 
                    'NT AUTHORITY\SYSTEM'
                }
                'LocalService'
                { 
                    'NT AUTHORITY\LOCAL SERVICE'
                }
                Default
                {
                    throw "IdentityType '$IdentityType' does not represent a built-in user"
                }
            }
        }
        catch
        {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}