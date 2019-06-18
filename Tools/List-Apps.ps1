function List-InstalledApps {
    param(
        $AppName,
        [switch]$IncludeUser
    )

    begin {

        $path   = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
        $path32 = 'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'

        # collect install information
        $products = get-childitem "hklm:\$path"

        if (test-path "hklm:\$path32") {
            $products += get-childitem "hklm:\$path32"
        }

        if ($IncludeUser) {
            # check if there's currently a loaded user hive
            if (test-path 'hkcu:\') {
                $products += get-childitem "hkcu:\$path"

                if (test-path "hkcu:\$path32") {
                    $products += get-childitem "hkcu:\$path32"
                }
            }
            
            # check if there are users loaded in memory
            new-psdrive -name hku -psprovider registry -root HKEY_USERS | out-null
            $availableUsers = (get-childitem 'hku:\').Name -replace 'HKEY_USERS\\'
            $userProfiles = get-ciminstance -classname win32_userprofile -filter 'SID LIKE "S-1-5-21%"'

            foreach ($availableUser in $availableUsers) {
                if ($availableUser -in $userProfiles.SID) {
                    $produces += get-childitem "hku:\$availableUser\$path"

                    if (test-path "hku:\$availableUser\$path32") {
                        $products += get-childitem "hku:\$availableUser\$path32"
                    }
                }
            }
        }

        $apps = @()

    }

    process {

        foreach ($product in $products) {

            if ($product.Property) {
                if ($product.GetValue("DisplayName") -ne $null) {

                    $name = $product.GetValue("DisplayName")

                    if ($name -like "*update for*") { Continue } #skip over updates

                    $version = $product.GetValue("DisplayVersion")

                    if ($product.GetValue("QuietUninstallString")) {
                        $uninstall = $product.GetValue("QuietUninstallString")
                    }
                    else {
                        $uninstall = $product.GetValue("UninstallString")
                    }
                }
                else{
                    Continue
                }
            }
            else{
                Continue
            }

            $app = new-object psobject
            $app | add-member -membertype noteproperty -name "AppName" -value $name
            $app | add-member -membertype noteproperty -name "Version" -value $version
            $app | add-member -membertype noteproperty -name "Uninstall" -value $uninstall

            $apps += $app
            $name = $null; $version = $null; $uninstall = $null
        }
        
    }

    end {

        $apps = $apps | sort AppName

        if ($AppName) {
            $apps = $apps | where{$_.AppName -like "*$($AppName)*"}
        }

        return $apps

    }

}
