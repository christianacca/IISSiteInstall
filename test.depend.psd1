@{ 
    PSDependOptions     = @{ 
        Target    = '$DependencyPath/_build-cache/'
        AddToPath = $true
    }
    PreferenceVariables = '1.0'
    IISAdministration   = '1.1.0.0'
    HostNameUtils       = @{
        Version    = '1.0.0'
        Parameters = @{
            Repository = 'christianacca-ps'
        }
    }
    IISSecurity         = @{
        Version    = '0.1.0'
        DependsOn  = 'PreferenceVariables'
        Parameters = @{
            Repository = 'christianacca-ps'
        }
    }
    IISConfigUnlock     = @{
        Version    = '0.1.0'
        DependsOn  = @('PreferenceVariables', 'IISAdministration')
        Parameters = @{
            Repository = 'christianacca-ps'
        }
    }
}