function Add-IISSiteBinding
{
    <#
    .SYNOPSIS
    Adds a port number to the existing collection of IIS site bindings
    
    .DESCRIPTION
    Adds a port number to the existing collection of IIS site bindings.
    
    .PARAMETER Name
    Name of an IIS Website
    
    .PARAMETER Port
    Port number to add

    .EXAMPLE
    Add-CaccaIISSiteBinding Series5 -Port 8080
    
    .NOTES
    The port number will be skipped for each existing endpoint that already binds that port
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Name,

        [ValidateRange(0, 65535)]
        [int] $Port
    )
    
    begin
    {
        Set-StrictMode -Version 'Latest'
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        function GetIISBinding
        {
            param([string]$SiteName)

            $list = Get-IISSiteBinding $SiteName
            # "unwrap" BindingCollection to make Binding object's easier to consume via 
            # the PS pipeline
            foreach ($item in $list)
            {
                $item
            }
        }
    }
    
    process
    {
        try
        {

            $existing = GetIISBinding $Name
            
            $portNeutralBindingInfo = $existing | ForEach-Object {
                $host = $_.Host
                $ip = $_.EndPoint.Address.ToString()
                if ($ip -eq '0.0.0.0')
                {
                    $ip = '*'
                }
                "$($ip):{0}:$host"
            } | Select-Object -Unique
            $candidateBindingInfo = $portNeutralBindingInfo | ForEach-Object {
                $_ -f $Port
            }

            $existingBindingInfo = $existing | Select-Object -Exp BindingInformation
            $newBinding = $candidateBindingInfo |
                Where-Object { $_ -notin $existingBindingInfo } |
                Select-Object @{ n = 'Name'; e = {$Name} }, @{ n = 'BindingInformation'; e = {$_} }

            $newBinding | New-IISSiteBinding
        }
        catch
        {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}