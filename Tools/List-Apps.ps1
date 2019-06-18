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
        $products = @()

        if (!$UserOnly) {
            # collect install information
            $products = get-childitem "hklm:\$path"

            if (test-path "hklm:\$path32") {
                $products += get-childitem "hklm:\$path32"
            }
        }

        if ($IncludeUser -or $UserOnly) {
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
