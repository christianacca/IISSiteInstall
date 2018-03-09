function Restart-AppPool
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification="Wrapper function for mocking")]
    param ([string] $Name)
    (Get-IISAppPool $Name).Recycle()
}