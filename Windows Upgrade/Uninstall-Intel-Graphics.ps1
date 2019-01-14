# This script handles Intel Graphics driver compatability errors Setup.exe will inevitably encounter
# when doing an upgrade from Windows 7 to Windows 10.
# This script is meant to be used with an "Upgrade Operating System" Task Sequence through ConfigMgr
# but can be run 'as-is' prior to running Setup.exe.

# Requirements: 
#   - devcon.exe (found in Windows Driver Kit (WDK) http://go.microsoft.com/fwlink/p/?LinkId=526733)
#   - script must reside in the same directory as devcon.exe
# Note: devcon.exe and devcon64.exe must exist or the script will encounter an error.
# devcon64.exe may not be necessary, but the system may handle 64-bit drivers differently,
# hence its inclusion. devcon64.exe is a rename of devcon.exe found in the x64 architecture directory
# of WDK.


# Define OS bit level
$bitness = (Get-WMIObject -Class win32_OperatingSystem).OSArchitecture

# Get all of the display drivers from WMI
$displayDriver = Get-WMIObject -Class win32_PnPSignedDriver | Where{$_.DeviceClass -eq 'DISPLAY'}

# Look for Intel(R) graphics drivers
ForEach($driver in $displayDriver){
    If($driver.DeviceName -like "*Intel*Graphics*"){
        # Stop the Intel Graphics service so that it may get uninstalled
        Try{Get-Service -DisplayName "*Intel*Graphics*" | Stop-Service}
        Catch{$_.Exception.Message}
        
        # Define necessary variables so driver may be uninstalled with Windows Utils
        $inf = $driver.InfName
        $compatID = $driver.compatID

        # Remove the inf package so that the driver cannot be auto-reinstalled
        Start pnputil -ArgumentList "-f -d $inf" -Wait -NoNewWindow

        # Uninstall the driver. OS Graphics may be affected
        If($bitness -eq "64-bit"){
            Start .\devcon64.exe -ArgumentList "remove `"$compatID`"" -Wait -NoNewWindow
        }
        Else{
            Start .\devcon.exe -ArgumentList "remove `"$compatID`"" -Wait -NoNewWindow
        }
    }
}
