@{ 
    PSDependOptions     = @{ 
        Target    = '$DependencyPath/_build-cache/'
        AddToPath = $true
    }
    PreferenceVariables = '1.0'
    IISAdministration   = '1.1.0.0'
    HostNameUtils       = @{
        Version    = '1.0.2'
    }
    IISSecurity         = @{
        Version    = '1.0.0'
        DependsOn  = 'PreferenceVariables'
    }
    IISConfigUnlock     = @{
        Version    = '1.0.0'
        DependsOn  = @('PreferenceVariables', 'IISAdministration')
    }
}