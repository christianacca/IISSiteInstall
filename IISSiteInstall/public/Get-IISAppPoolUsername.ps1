function Get-IISAppPoolUsername {
    <#
    .SYNOPSIS
    Returns the Username used as the Identity for an IIS AppPool
    
    .DESCRIPTION
    Returns the Username used as the Identity for an IIS AppPool. This will either be
    the domain qualified name of a specific Windows User account or the qualified name
    of the built-in accounts (eg 'NT Authority\System'), which ever is assigned as the
    Identity of the AppPool
    
    .PARAMETER InputObject
    The AppPool to return a username
    
    .EXAMPLE
    Get-IISAppPool DefaultAppPool | Get-CaccaIISAppPoolUsername
    
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [Microsoft.Web.Administration.ApplicationPool] $InputObject
    )
    
    begin {
        Set-StrictMode -Version 'Latest'
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'
    }
    
    process {
        try {
            try {
                ConvertTo-BuiltInUsername ($InputObject.ProcessModel.IdentityType) ($InputObject.Name)
            }
            catch {
                $InputObject.ProcessModel.UserName
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}