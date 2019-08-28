<#
.SYNOPSIS
    This script will delete local profiles older than $days

.DESCRIPTION
    Taking user input via parameters, the script will check a local system's 
    WMI and find profiles that have not established a network authentication
    in the specified timeframe. Any account that is outside the timeframe will
    attempt to be removed from the local system.

.PARAMETER
    Days
        An interger that specifies the amount, in days, of time elapsed since
        an account has last logged into a machine.

.NOTES
    Version:       1.0
    Author:        Chris Richards
    Creation Date: August 26, 2019

.EXAMPLE
    powershell.exe -path "<full path to file>\old-profile.ps1" -days [int]

#>
param (
    [parameter(mandatory=$true)]
    [ValidateNotNullorEmpty()]
    [int[]]$days
)

# get info on user's that have accessed the system
# info is generated based on user profile events
$userAccessInfo = @()
$data = get-winevent -filterhashtable @{LogName = 'Microsoft-Windows-User Profile Service/Operational'; Id = '67'}

foreach ($datum in $data) {
    if($datum.Properties[1].Value -notin $userAccessInfo.Path){
        $temp = [pscustomobject]@{
            'LastAccess' = $datum.TimeCreated
            'Path' = $datum.Properties[1].Value
        }
        
        $userAccessInfo += $temp
    }
}

# get all the locally built profiles on the system, excluding
# special system accounts
$localProfiles = get-wmiobject -class win32_UserProfile -filter "Special=$false" |
    select-object *

# attempt to remove profiles older than $days
foreach ($user in $userAccessInfo) {
    
    # declare the user's last access time
    $lastAccess = $user.LastAccess

    # make the comparison date $days prior to $now
    $dateCompare = (get-date).AddDays(-$($days))
    
    if ($lastAccess -le $dateCompare) {
        $pathName = $user.Path
        
        # just because it's in the logs doesn't mean it's still there
        # check for the existence of the user
        if ($pathName -in $localProfiles.LocalPath){
            try {
                ($localProfiles | where {$_.LocalPath -match $pathName}).Delete()
                write-output "$pathName has been removed; last access was $lastAccess"
            }
            catch {
                $_.exception.message
            }
        }

    }

}
