<#
.SYNOPSIS
    This script will delete local profiles older than $days

.DESCRIPTION
    Taking user input via parameters, the script will check a local system's 
    event log/registry and find profiles that have not generated a logon session
    in the specified timeframe. Any account that is outside the timeframe will
    attempt to be removed from the local system.

.PARAMETER
    Days
        An interger that specifies the amount, in days, of time elapsed since
        an account has last logged into a machine.

.NOTES
    Version:       2.0
    Author:        Chris Richards
    Creation Date: August 26, 2019
    Revision Date: August 30, 2019

.EXAMPLE
    powershell.exe -path "<full path to file>\old-profile.ps1" -days [int]

#>
param (
    #[parameter(mandatory=$true)]
    #[ValidateNotNullorEmpty()]
    [int[]]$days = 90
)

# code signature for advapi32:RegQueryInfoKey
$signature = @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public class advapi32
{
    [DllImport("advapi32.dll", CharSet = CharSet.Auto, EntryPoint = "RegQueryInfoKey", SetLastError = true)]
    public static extern IntPtr RegQueryInfoKey(
        Microsoft.Win32.SafeHandles.SafeRegistryHandle hKey, StringBuilder lpClass,
        ref int lpcbClass, int lpReserved, ref int lpcSubKeys, ref int lpcbMaxSubKeyLen,
        ref int lpcbMaxClassLen, ref int lpcValues, ref int lpcbMaxValueNameLen,
        ref int lpcbMaxValueLen, ref int lpcbSecurityDescriptor, ref long lpftLastWriteTime
    );
}
"@

# make the comparison date $days prior to $now
$dateCompare = (get-date).AddDays(-$($days))

# get all the locally built profiles on the system, excluding
# special system accounts
$localProfiles = get-wmiobject -class win32_UserProfile -filter "Special=$false" |
    select-object *

# get info on user's that have accessed the system
# info is generated based on user profile events
$userAccessInfo = @()
$data = get-winevent -filterhashtable @{LogName = 'Microsoft-Windows-User Profile Service/Operational'; Id = '67'} | where {$_.Properties[1].Value -notlike "$env:windir\ServiceProfiles*"}

foreach ($datum in $data) {

    if($datum.Properties[1].Value -notin $userAccessInfo.Path){

        $temp = [pscustomobject]@{
            'LastAccess' = $datum.TimeCreated
            'Path' = $datum.Properties[1].Value
        }
        
        $userAccessInfo += $temp

    }

}

# if the machine was recently serviced, we want the 
# historical data as well
if (test-path 'C:\Windows.old\WINDOWS\System32\winevt\Logs\Microsoft-Windows-User Profile Service%4Operational.evtx') {

    $path = 'C:\Windows.old\WINDOWS\System32\winevt\Logs\Microsoft-Windows-User Profile Service%4Operational.evtx'
    $data = get-winevent -filterhashtable @{Path = $path; Id = '67'}

    foreach ($datum in $data) {

        if($datum.Properties[1].Value -notin $userAccessInfo.Path){
            $temp = [pscustomobject]@{
                'LastAccess' = $datum.TimeCreated
                'Path' = $datum.Properties[1].Value
            }
        
            $userAccessInfo += $temp

        }

    }

}

# check if all profiles have been accounted for
$count = $localProfiles.Count - $userAccessInfo.Count
if ($count -gt 0) {
    # there are some descrepancies and we'll have to dig deeper
    $moreInfoRequired = $true
}

# Dig up more information if needed
if ($moreInfoRequired) {
    write-host "need more info"

    Function Get-RegKeyLastWriteTime {
        param(
            [parameter(ValueFromPipeline=$true, ParameterSetName='ByValue')]
            [Microsoft.Win32.RegistryKey]$regKey
        )

        begin {
            # load the necessary windows function for checking registry
            # LastWriteTime properties
            try {
                [void][advapi32]
            }
            catch {
                add-type -TypeDefinition $signature
            }
        }

        process {
            # define variables for regkey processing
            $classLength = 255
            $className = new-object system.text.stringbuilder $regKey.Name
            $regHandle = $regKey.Handle
            $timestamp = $null

            # retrieve the registry values with the information given
            $result = [advapi32]::RegQueryInfoKey(
                $regHandle, $className, [ref]$classLength,
                $null, [ref]$null, [ref]$null, [ref]$null,
                [ref]$null, [ref]$null, [ref]$null,
                [ref]$null, [ref]$timestamp
            )

            # process the results for the return
            switch ($result) {
                0 {
                    $timestamp = [datetime]::FromFileTime($timestamp)
                }

                Default {
                    throw "Well, that didn't work... Error Code: $result"
                }
            }
        }

        end {
            return $timestamp
        }

    }

    $moreInfo = @()

    # declare ProfileList root path
    $profileList = 'hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'

    foreach ($profile in $localProfiles) {

        $sid = $profile.SID
        $key = "$profileList\$sid"
    
        if (test-path $key) {

            $key = get-item -path $key
            $result = ($key | Get-RegKeyLastWriteTime)

            $temp = [pscustomobject]@{
                'LastAccess' = $result
                'Path' = $profile.LocalPath
            }

            $moreInfo += $temp
   
        }

    }

    # get the profiles that aren't in the event log data
    # treat all missing accounts like the oldest verifiable
    # account found in the logs
    $cloneTime = ($userAccessInfo | select -last 1).LastAccess

    # there's a fairly good chance that missing profiles have
    # servicing migration timestamps from Feature Updates
    $setup = 'c:\windows\panther\setup.exe'
    if (test-path $setup) {
        $servicingTime = ((get-item -path $setup).LastWriteTime).ToString("MM/dd/yyyy hh:mm")
    }

    foreach ($profile in $moreInfo) {

        if ($profile.Path -notin $userAccessInfo.Path) {
            $simpleTime = ($profile.LastAccess).ToString("MM/dd/yyyy hh:mm")

            if ($simpleTime -eq $servicingTime) {
                $timestamp = $cloneTime
            }
            else {
                $timestamp = $profile.LastAccess
            }

            $temp = [pscustomobject]@{
                'LastAccess' = $timestamp
                'Path' = $profile.Path
            }

            $userAccessInfo += $temp

        }

    }

}

# just to be safe!
$userAccessInfo = $userAccessInfo | where {$_.Path -notlike "$env:windir\ServiceProfiles*"}

# begin the removal process
# this is a best-effort process, so it could potentially fail
# on some profiles
foreach ($user in $userAccessInfo) {

    if ($user.LastAccess -le $dateCompare) {
    
        try {
            $Obj = (get-wmiobject -class win32_userprofile | where {$_.Localpath -eq $user.Path})
            If($Obj) {
                $Obj.Delete()
                write-output "removed $($user.Path)"
            }
        }
        catch {
            $_.exception.message
        }

    }

}
