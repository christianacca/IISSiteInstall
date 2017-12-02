function Set-IISAppPoolUser {
    <#
    .SYNOPSIS
    Set the Windows account identity of the App Pool
    
    .DESCRIPTION
    Set the Windows account identity of the App Pool
    
    .PARAMETER Credential
    The credential of a specific account to assign as the identity
    
    .PARAMETER IdentityType
    The built-in windows account to assign as the identity
    
    .PARAMETER InputObject
    The App Pool whose identity is to be assigned
    
    .PARAMETER Commit
    Save changes to IIS immediately? Defaults to true
    
    .EXAMPLE
    Get-IISAppPool MyAppPool | Set-CaccaIISAppPoolUser -IdentityType ApplicationPoolIdentity

    Description
    -----------
    Set the identity of the app ppol to use ApplicationPoolIdentity. In this example, the virtual
    user 'IIS AppPool\MyAppPool' will be assigned as the Windows identity

    .EXAMPLE
    $pswd = ConvertTo-SecureString '(mypassword)' -AsPlainText -Force
    $creds = [PsCredential]::new("$($env:COMPUTERNAME)\MyLocalUser", $pswd)

    New-CaccaIISAppPool $tempAppPool -Config {
        $_ | Set-CaccaIISAppPoolUser $creds -Commit:$false
    }

    Description
    -----------
    Create an pool with an identity assigned to a specific user account
    
    #>
    [CmdletBinding(DefaultParameterSetName='None')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'SpecificUser', Position = 0)]
        [PsCredential] $Credential,

        [Parameter(Mandatory, ParameterSetName = 'CommonIdentity', Position = 0)]
        [ValidateSet('ApplicationPoolIdentity', 'LocalService', 'LocalSystem', 'NetworkService')]
        [string] $IdentityType,

        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [Microsoft.Web.Administration.ApplicationPool] $InputObject,
        
        [switch] $Commit
    )
    
    begin {
        Set-StrictMode -Version 'Latest'
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        if (!$PSBoundParameters.ContainsKey('Commit')) {
            $Commit = $true
        }
    }
    
    process {
        try {

            if ($PSCmdlet.ParameterSetName -eq 'CommonIdentity') {
                $dummyPassword = ConvertTo-SecureString 'dummy' -AsPlainText -Force
                $username = ConvertTo-BuiltInUsername $IdentityType ($InputObject.Name)
                $Credential = [PsCredential]::new($username, $dummyPassword)
            }

            if ($Commit) {
                Start-IISCommitDelay
            }
            try {
                if ($Credential.UserName -like 'IIS AppPool\*'){
                    $InputObject.ProcessModel.IdentityType = 'ApplicationPoolIdentity'
                } elseif($Credential.UserName -eq 'NT AUTHORITY\NETWORK SERVICE') {
                    $InputObject.ProcessModel.IdentityType = 'NetworkService'
                } elseif ($Credential.UserName -eq 'NT AUTHORITY\SYSTEM') {
                    $InputObject.ProcessModel.IdentityType = 'LocalSystem'
                } elseif ($Credential.UserName -eq 'NT AUTHORITY\LOCAL SERVICE') {
                    $InputObject.ProcessModel.IdentityType = 'LocalService'
                } else {
                    $InputObject.ProcessModel.UserName = $Credential.UserName
                    $InputObject.ProcessModel.Password = $Credential.GetNetworkCredential().Password
                    $InputObject.ProcessModel.IdentityType = 'SpecificUser'
                }
                if ($Commit) {
                    Stop-IISCommitDelay
                }       
            }
            catch {
                if ($Commit) {
                    Stop-IISCommitDelay -Commit:$false
                }
                throw
            }
            finally {
                if ($Commit) {
                    # make sure subsequent scripts will not fail because the ServerManger is now readonly
                    Reset-IISServerManager -Confirm:$false
                }
            }

        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
}