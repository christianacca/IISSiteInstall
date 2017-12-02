Function Compare-ObjectProperties {
    Param(
        [PSObject]$ReferenceObject,
        [PSObject]$DifferenceObject 
    )
    $objprops = $ReferenceObject | Get-Member -MemberType Property,NoteProperty | % Name
    $objprops += $DifferenceObject | Get-Member -MemberType Property,NoteProperty | % Name
    $objprops = $objprops | Sort | Select -Unique
    $diffs = @()
    foreach ($objprop in $objprops) {
        $diff = Compare-Object $ReferenceObject $DifferenceObject -Property $objprop
        if ($diff) {            
            $diffprops = @{
                PropertyName=$objprop
                RefValue=($diff | ? {$_.SideIndicator -eq '<='} | % $($objprop))
                DiffValue=($diff | ? {$_.SideIndicator -eq '=>'} | % $($objprop))
            }
            $diffs += New-Object PSObject -Property $diffprops
        }        
    }
    if ($diffs) {return ($diffs | Select PropertyName,RefValue,DiffValue)}     
}