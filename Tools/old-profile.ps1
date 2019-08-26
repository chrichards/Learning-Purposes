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

# get info on users that have authenticated with the domain
# and logged into the system
$netProfiles = get-wmiobject -class win32_NetworkLoginProfile | 
    where {$_.Name -notlike 'NT AUTHORITY*'} | select-object *

# get all the locally built profiles on the system, excluding
# special system accounts
$localProfiles = get-wmiobject -class win32_UserProfile -filter "Special=$false" |
    select-object *

# attempt to remove profiles older than $days
foreach ($netProfile in $netProfiles) {
    
    # convert the WMI time to standard powershell format
    if ($netProfile.LastLogon -ne $null) {
        $lastLogon = [System.Management.ManagementDateTimeConverter]::ToDateTime($netProfile.LastLogon)
    }
    # if the time is null, make it the original reference time
    else {
        $lastLogon = "01/01/1970 00:00:00"
    }

    # make the comparison date $days prior to $now
    $dateCompare = (get-date).AddDays(-$($days))

    
    if ($lastLogon -le $dateCompare) {
        $pathName = ($netProfile.Name).Split("\")[1]
        
        try {
            ($localProfiles | where {$_.LocalPath -match $pathName}).Delete()
            write-output "$pathName has been removed"
        }
        catch {
            $_.exception.message
        }

    }

}
