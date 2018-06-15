Param(
    [parameter(Mandatory=$true)]
    [ValidateSet("Add","Check","Remove")]
    [string]$Action,

    [ValidateNotNullorEmpty()]
    [int]$Count,

    [parameter(Mandatory=$true)]
    [ValidateNotNullorEmpty()]
    [string]$AdminPass
)

# Figure out what type of OS is running and define where the PGP directory is
$OS_bitness = (Get-WMIObject -Class win32_OperatingSystem).OSArchitecture
If($OS_bitness -eq "32-bit"){$Symantec_Encryption_Path = "$env:ProgramFiles\PGP Corporation\PGP Desktop"}
If($OS_bitness -eq "64-bit"){$Symantec_Encryption_Path = "${env:ProgramFiles(x86)}\PGP Corporation\PGP Desktop"}

# Make sure PGPWDE actually exists, exit if it doesn't
$PGPWDE = "$Symantec_Encryption_Path\pgpwde.exe"
If(-Not(Test-Path -Path "$PGPWDE")){
    Write-Host "PGPWDE could not be found!"
    Exit(1)
}

# Make the process output available for interpretation
$Process_Output = New-Object System.Diagnostics.ProcessStartInfo
    $Process_Output.FileName = $PGPWDE
    $Process_Output.RedirectStandardError = $true
    $Process_Output.RedirectStandardOutput = $true
    $Process_Output.UseShellExecute = $false 

# Add an admin bypass; check output until successful
If($Action -eq "Add"){
    Do{
        $Process_Output.Arguments = "--add-bypass --disk 0 --count $count --admin-passphrase $AdminPass"
        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $Process_Output
        $Process.Start() | Out-Null
        $Process.WaitForExit()
        $Output = $Process.StandardOutput.ReadToEnd()

        If($Output -match "successful"){$Bootguard_Bypass = $true}
        If($Output -match "failed"){
            If($Output -match "-12237"){
                # A bypass is already in place. The bypass should be removed so the specified
                # count may be implemented.
                Write-Host "Removing previous bypass for new bypass."
                Start-Process $PGPWDE -ArgumentList "--remove-bypass --disk 0 --admin-passphrase $AdminPass" -Wait -WindowStyle Hidden
            }
            Else{
                # Some other error is preventing the bypass.
                Write-Host "Cannot create bypass."
                Write-Host $Output
                Exit($Process.ExitCode)
            }
        }
    }Until($Bootguard_Bypass -eq $true)

    Write-Host "Bypass successfully created!"
    Exit($Process.ExitCode)
}

# Check if a bypass has been set
If($Action -eq "Check"){
    $Process_Output.Arguments = "--check-bypass --disk 0 --admin-passphrase $AdminPass"
    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $Process_Output
    $Process.Start() | Out-Null
    $Process.WaitForExit()
    $Output = $Process.StandardOutput.ReadToEnd()

    If($Output -match "Enabled"){
        $Result = ($Output -Split '[\r]')[1]
        Write-Host "Bypass is enabled."
        Write-Host $Result
    }
    If($Output -match "Disabled"){
        Write-Host "No bypass has been set."
    }
    If($Process.ExitCode -ne 0){
        Write-Host "Unable to perform a bypass check with PGPWDE"
        Write-Host $Output
        Exit($Process.ExitCode)
    }
    Else{Exit($Process.ExitCode)}
}

# Remove a bypass request from the system
# NOTE: you cannot remove a number of requests from the total granted (e.g. remove 2 reboots from 5 granted)
# This is an "all or nothing" effort built into PGPWDE
If($Action -eq "Remove"){
    $Process_Output.Arguments = "--remove-bypass --disk 0 --admin-passphrase $AdminPass"
    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $Process_Output
    $Process.Start() | Out-Null
    $Process.WaitForExit()
    $Output = $Process.StandardOutput.ReadToEnd()

    If($Output -match "successful"){Write-Host "Bypass removed successfully."}
    If($Output -match "failed"){
        If($Output -match "-11984"){
            Write-Host "A bypass request does not exist; no action taken."
        }
        Else{
            Write-Host "There is a problem with PGPWDE."
            Write-Host $Output
            Exit($Process.ExitCode)
        }
    }
    Exit($Process.ExitCode)
}
