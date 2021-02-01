<#
.SYNOPSIS
  Name: list-apps.ps1
  This script allows you to list installed applications on a computer.

.DESCRIPTION
  List-apps.ps1 was made for a faster query of installed applications rather than relying
  on a WMI query to win32_product. This script automatically does a wildcard lookup if
  looking for a specific installed app. It also includes the ability to see what user-based
  applications are installed on a machine.

.PARAMETER AppName
  Specifies the DisplayName of the application you're trying to find. This parameter
  is processed as a wildcard so an exact name is not necessary.

.PARAMETER IncludeUser
  A switch that checks through loaded userprofiles for installed applications.
  
.PARAMETER UserOnly
  A switch that looks ONLY at user installations. This parameter cannot be used in conjunction
  with 'IncludeUser'.

.NOTES
  Created: 6/6/2019
  Release: 6/18/2019
  Updated: 2/1/2021
  Author: Chris Richards

  This function can be placed into a script and called within the script OR
  loaded into a console session and run from there. To load this function into
  the active console session, use the command:
    . "<path to script>\list-apps.ps1"

.EXAMPLE
  To list all SYSTEM applications that appear in Add/Remove Programs, run:
  List-InstalledApps

.EXAMPLE
  Check to see if Microsoft Office is installed on the computer:
  List-InstalledApps -AppName Office

.EXAMPLE
  Run the function with the '-IncludeUser' switch to include installations that 
  have rooted themselves in a user's profile:
  List-InstalledApps -IncludeUser

#>


function List-InstalledApps {
    param(
        $AppName,
        [switch]$IncludeUser,
        [switch]$UserOnly
    )

    begin {

        if ($IncludeUser -and $UserOnly) {
            write-error 'You cannot use these parameters together: IncludeUser, UserOnly.'
            break
        }

        $path   = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
        $path32 = 'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
        $products = [System.Collections.ArrayList]::new()

        if (!$UserOnly) {
            # collect install information
            get-childitem "hklm:\$path" | % {$products.Add($_) | Out-Null}

            if (test-path "hklm:\$path32") {
                get-childitem "hklm:\$path32" | % {$products.Add($_) | Out-Null}
            }
        }

        if ($IncludeUser -or $UserOnly) {
            # check if there's currently a loaded user hive
            if (test-path 'hkcu:\') {
                get-childitem "hkcu:\$path" | % {$products.Add($_) | Out-Null}

                if (test-path "hkcu:\$path32") {
                    get-childitem "hkcu:\$path32" | % {$products.Add($_) | Out-Null}
                }
            }
            
            # check if there are users loaded in memory
            new-psdrive -name hku -psprovider registry -root HKEY_USERS | out-null
            $availableUsers = (get-childitem 'hku:\').Name -replace 'HKEY_USERS\\'
            $userProfiles = get-ciminstance -classname win32_userprofile -filter "special=$false"

            foreach ($userProfile in $userProfiles) {
                if (($userProfile.SID -in $availableUsers) -and ($userProfile.Loaded -eq $false)) {
                    $sid = $userProfile.SID
                    get-childitem "hku:\$sid\$path" | % {$products.Add($_) | Out-Null}

                    if (test-path "hku:\$sid\$path32") {
                        get-childitem "hku:\$sid\$path32" | % {$products.Add($_) | Out-Null}
                    }
                }
            }
        }

        $apps = [System.Collections.ArrayList]::new()

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

            $app = [PsCustomObject]@{
                "AppName"   = $name
                "Version"   = $version
                "Uninstall" = $uninstall
            }

            $apps.Add($app) | Out-Null
            $name = $version = $uninstall = $null
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
