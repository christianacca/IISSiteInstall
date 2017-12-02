function Get-IISSiteHierarchyInfo
{
    <#
    .SYNOPSIS
    Returns the physical paths and the User Identity assigned to IIS websites and their child Applications
    
    .DESCRIPTION
    Returns the physical paths and the User Identity assigned to IIS websites and their child Applications
    
    .PARAMETER Name
    The name of the IIS Website to filter results
    
    .PARAMETER AppName
    The name of the IIS Web application to filter results
    
    .EXAMPLE
    Get-CaccaIISSiteHierarchyInfo Series5

    Output
    ------
	Site_Name            : Series5
	App_Path             : /
	App_PhysicalPath     : C:\inetpub\sites\Series5AppPool_Name         : Series5-AppPool
	AppPool_IdentityType : ApplicationPoolIdentity
	AppPool_Username     : IIS AppPool\Series5-AppPool

	Site_Name            : Series5
	App_Path             : /Spa
	App_PhysicalPath     : C:\Git\Series5\src\Ram.Series5.Spa
	AppPool_Name         : Series5-AppPool
	AppPool_IdentityType : ApplicationPoolIdentity
	AppPool_Username     : IIS AppPool\Series5-AppPool

    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string] $Name,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $AppName
    )
    
    begin
    {
        Set-StrictMode -Version 'Latest'
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'
    }
    
    process
    {
        try
        {
            $siteParams = if ([string]::IsNullOrWhiteSpace($Name))
            {
                @{}
            }
            else
            {
                @{
                    Name = $Name.Trim()
                }
            }

            if (![string]::IsNullOrWhiteSpace($AppName) -and !$AppName.StartsWith('/'))
            {
                $AppName = '/' + $AppName
            }

            Get-IISSite @siteParams -PV site -WA SilentlyContinue |
                Select-Object -Exp Applications -PV app |
                Where-Object { !$AppName -or $_.Path -eq $AppName } |
                ForEach-Object {
                $existingPool = Get-IISAppPool -Name $_.ApplicationPoolName -WA SilentlyContinue
                if (!$existingPool)
                {
                    ''
                }
                else
                {
                    $existingPool
                }
            } -PV pool |
                Select-Object  `
            @{n = 'Site_Name'; e = {$site.Name}},
            @{n = 'App_Path'; e = {$app.Path}}, 
            @{n = 'App_PhysicalPath'; e = {$app.VirtualDirectories[0].PhysicalPath}}, 
            @{n = 'AppPool_Name'; e = { if ($pool) { $app.ApplicationPoolName } }},
            @{n = 'AppPool_IdentityType'; e = { if ($pool) { $pool.ProcessModel.IdentityType} }},
            @{n = 'AppPool_Username'; e = { if ($pool) { Get-IISAppPoolUsername $pool } }}
        }
        catch
        {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}