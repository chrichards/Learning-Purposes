function New-RandomPassword {
    # Declare the legal contents of the password
    $alphabet = (97..122) | %{([char]$_).ToString()}
    $symbols  = @("!","@","#","$","%","&","*","?","_")
    $numbers  = (0..9)

    # Create the base password
    $base = Get-Random -InputObject $alphabet -Count 12

    # Define the random number subroutine
    $randomcnt = {Get-Random -Minimum 2 -Maximum 4}
    $randompos = {Get-Random -InputObject (0..($base.Length - 1)) -Count $(&$randomcnt)}

    # Capitalize some of the letters
    &$randompos | %{$base[$_] = $base[$_].ToUpper()}

    # Make a unified string
    $base = $base -Join ''

    # Insert some numbers
    &$randompos | %{$base = $base.Insert($_, $(Get-Random -InputObject $numbers))}

    # Insert some symbols
    &$randompos | %{$base = $base.Insert($_, $(Get-Random -InputObject $symbols))}

    $obj = [PsCustomObject]@{
        'RawPassword'  = $base
        'SecureString' = ($base | ConvertTo-SecureString -AsPlainText -Force)
    }

    return $obj
}
