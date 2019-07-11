param(
    $x, $y, $z
)

function Get-DriverPackageInformation {
    
    [CmdletBinding()]
    param(
        $server,
        $credentials,
        $site_code

    )

    begin {

        $cpu_model = (Get-WmiObject -Class win32_ComputerSystem).Model

    }

    process {

        Write-Host "Checking for driver records."
        $driver_package = Get-WmiObject -Namespace "Root\SMS\Site_$($site_code)" `
            -Class "SMS_DriverPackage" -ComputerName $server -credential $credentials | 
                Where{$_.DriverModel -eq $cpu_model}


        if ($driver_package) {

            Write-Host "A driver package exists for your computer model."
            $packageID = $driver_package.PackageID
        
        }

        else {

            Write-Host "A driver package was not available for your computer model."
        
        }

    }

    end {

        $result = [pscustomobject]@{
            site_code = $site_code
            sms_provider = $sms_provider
            packageID = $packageID
            model = $cpu_model
        }

        return $result

    }

}

# define some credentials
$key = (1..16)
$username = $z
$password = ($y | ConvertTo-SecureString -Key $key)
$creds = new-object system.management.automation.pscredential -argumentlist ($username,$password)

# connect to the task sequence environment
$TSvar = New-Object -ComObject Microsoft.SMS.TSEnvironment

# gather information
$site_code = $TSvar.Value("_SMSTSAssignedSiteCode")
$info = Get-DriverPackageInformation -server $x -credentials $creds -site_code $site_code

# if driver info is returned, process it
# otherwise, let the TS know you wanna do an auto-apply
if ($info.packageID) {

    $TSvar.Value("OSDDownloadDownloadPackages") = $info.packageID
    $TSvar.Value("OSDDownloadDestinationLocationType") = "TSCache"

    write-host "Downloading drivers..."
    start-process OSDDownloadContent -wait -windowstyle hidden

}

else {
    
    $TSvar.Value("AutoApply") = $true
    Break

}

# recurvisely apply all of the drivers that were downloaded
# define paths
$TSroot = "C:\_SMSTaskSequence"
$content_dir = "$TSroot\Packages\$($info.packageID)"

# define some TSManager information
write-host "Preparing to update the TS progress module"
$TSProgressUI = New-Object -ComObject Microsoft.SMS.TSProgressUI
$org = $TSvar.Value('_SMSTSOrgName')
$package = $TSvar.Value('_SMSTSPackageName')
$custom = $TSvar.Value('_SMSTSCustomProgressDialogMessage')
$currentAction = $TSvar.Value('_SMSTSCurrentActionName')
$uStep = [Convert]::ToUInt64($TSvar.Value('_SMSTSNextInstructionPointer'))
$uMaxStep = [Convert]::ToUInt64($TSvar.Value('_SMSTSInstructionTableSize'))
$message = "Applying drivers for $($info.model)"

# spin up the dism process
write-host "Starting the DISM procress"
$process = start-process cmd -argumentlist "/c dism /Image:C:\ /Add-Driver /Driver:$content_dir /Recurse /Forceunsigned >> X:\WINDOWS\TEMP\SMSTSLog\dism.log" -passthru -windowstyle hidden

# wait for the log to become available
do {

    $test = Test-Path -Path "X:\WINDOWS\TEMP\SMSTSLog\dism.log"

} until( $test -eq $true )

# begin processing the log for progress information
do {

    $log = Get-Content -Path "X:\WINDOWS\TEMP\SMSTSLog\dism.log" -Tail 1

    if ($log -notmatch "Installing") { Continue }
    else {

        $progressTotal = (($log).Split("-")[0] -replace "Installing\s\d+\sof.").Trim()
        $progress = (($log).Split("of")[0] -replace "Installing\s").Trim()

        $progressTotal = [Convert]::ToUInt64($progressTotal)
        $progress = [Convert]::ToUInt64($progress)
        $TSProgressUI.ShowActionProgress($org,$package,$custom,$currentAction,$uStep,$uMaxStep,$message,$progress,$progressTotal)

    }

} until ( $log -match 'The operation completed successfully.' )

# wait for dism to stop before finishing
Wait-Process $process.Id
