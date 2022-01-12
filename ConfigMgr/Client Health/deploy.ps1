Param ($cmg)

$script = {


Param (
    $CMG
)

# Variable declaration zone!
$services = @{
    "BITS" = "delayed-auto"
    "lanmanserver" = "auto"
    "RpcSs" = "auto"
    "winmgmt" = "auto"
    "wuauserv" = "delayed-auto"
    "w32Time" = "auto"
}

# A standard output logging function
Function global:Write-Log {
    Param (
        [switch]$header,
        $message,
        $component,
        $type # 1 = normal; 2 = warning; 3 = error
    )

    $log = "$($env:temp)\$($env:COMPUTERNAME)-ClientHealth.log"
    $time = (Get-Date -Format "hh:mm:ss.ms")
    $date = (Get-Date -Format "MM-dd-yyyy")

    $digest = "<![LOG[$message]LOG]!><time=`"$time`" date=`"$date`" component=`"$component`" context=`"`" type=`"$type`" thread=`"`" file=`"`">"

    If (-Not(Test-Path -Path $log)) {
        $null | Out-File -FilePath $log -Encoding utf8
    }
    ElseIf (Test-Path -Path $log) {
        $file = Get-Item -Path $log

        # If the file is too big, we wanna make a new one
        # Otherwise, append a big old separator line for ease of reading
        If (([math]::round($file.length / 1KB)) -gt 50) {
            $count = (Get-ChildItem -Path "$($env:temp)\$($env:computername)-ClientHealth (*").Count

            If ($count -ge 1) {
                $i = $count + 1
            }
            Else {
                $i = 1
            }

            Rename-Item -Path $log -NewName "$($env:temp)\$($env:computername)-ClientHealth ($i).log"
            $null | Out-File -FilePath $log -Encoding utf8
        }
        
        If ($header) {
            $spacer = "##############################"
            $tmpmessage = $spacer + " $(Get-Date -Format f) " + $spacer
            $tmpdigest = "<![LOG[$tmpmessage]LOG]!><time=`"$(Get-Date -Format "hh:mm:ss.ms")`" date=`"$date`" component=`"$component`" context=`"`" type=`"$type`" thread=`"`" file=`"`">"
            $tmpdigest | Add-Content -Path $log
        }

    }

    $digest | Add-Content -Path $log

}

# A function for quickly looking through the registry to see what's installed
Function global:List-InstalledApps {
    Param(
        $AppName,
        [switch]$IncludeUser,
        [switch]$UserOnly
    )

    Begin {

        If ($IncludeUser -and $UserOnly) {
            Write-Error 'You cannot use these parameters together: IncludeUser, UserOnly.'
            Break
        }

        $path   = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
        $path32 = 'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
        $products = [System.Collections.ArrayList]::new()

        If (!$UserOnly) {
            # collect install information
            Get-ChildItem "hklm:\$path" | % {$products.Add($_) | Out-Null}

            If (Test-Path "hklm:\$path32") {
                Get-ChildItem "hklm:\$path32" | % {$products.Add($_) | Out-Null}
            }
        }

        If ($IncludeUser -or $UserOnly) {
            # check if there's currently a loaded user hive
            If (Test-Path 'hkcu:\') {
                Get-ChildItem "hkcu:\$path" | % {$products.Add($_) | Out-Null}

                If (Test-Path "hkcu:\$path32") {
                    Get-ChildItem "hkcu:\$path32" | % {$products.Add($_) | Out-Null}
                }
            }
            
            # check if there are users loaded in memory
            New-PsDrive -Name hku -PsProvider registry -Root HKEY_USERS | Out-Null
            $availableUsers = (Get-ChildItem 'hku:\' -ErrorAction SilentlyContinue).Name -replace 'HKEY_USERS\\'
            $userProfiles = Get-CimInstance -ClassName win32_userprofile -Filter 'SID LIKE "S-1-5-21%" OR SID LIKE "S-1-5-12%"'

            ForEach ($availableUser in $availableUsers) {
                If ($availableUser -in $userProfiles.SID) {
                    Get-ChildItem "hku:\$availableUser\$path" | % {$products.Add($_) | Out-Null}

                    If (Test-Path "hku:\$availableUser\$path32") {
                        Get-ChildItem "hku:\$availableUser\$path32" | % {$products.Add($_) | Out-Null}
                    }
                }
            }
        }

        $apps = [System.Collections.ArrayList]::new()

    }

    Process {

        ForEach ($product in $products) {

            If ($product.Property) {
                If ($product.GetValue("DisplayName") -ne $null) {

                    $name = $product.GetValue("DisplayName")

                    If ($name -like "*update for*") { Continue } #skip over updates

                    $version = $product.GetValue("DisplayVersion")

                    If ($product.GetValue("QuietUninstallString")) {
                        $uninstall = $product.GetValue("QuietUninstallString")
                    }
                    Else {
                        $uninstall = $product.GetValue("UninstallString")
                    }

                    If ($product.PsChildName -match "^{.*}$") {
                        $MsiCode = $product.PsChildName
                    }
                    Else {
                        $MsiCode = "Non-MSI"
                    }
                }
                Else{
                    Continue
                }
            }
            Else{
                Continue
            }

            $app = [PsCustomObject]@{
                "MsiCode"   = $MsiCode
                "AppName"   = $name
                "Version"   = $version
                "Uninstall" = $uninstall
            }

            $apps.Add($app) | Out-Null
            $name = $version = $uninstall = $null
        }
        
    }

    End {

        $apps = $apps | sort AppName

        If ($AppName) {
            $apps = $apps | ? {$_.AppName -like "*$($AppName)*"}
        }

        Return $apps

    }

}


# Figure out which adapter is connected to AD, its IP, and maybe more!
Function Get-ADConnectionInformation {

    # First off, was the machine domain joined?
    $domain = (Get-CimInstance -ClassName win32_ComputerSystem).Domain

    If ($domain -eq 'WORKGROUP') {
        $domain = (Get-ItemProperty -Path 'hklm:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'DhcpDomain').DhcpDomain
    }

    # What logon server are we connecting to?
    # Since the command being run doesn't have a PS equivalent
    # we need output redirection from the exe itself
    $system = [System.Environment]::SystemDirectory
    $procInfo = New-Object System.Diagnostics.ProcessStartInfo
    $procInfo.FileName = "$system\nltest.exe"
    $procInfo.RedirectStandardOutput = $true
    $procInfo.RedirectStandardError = $true
    $procInfo.UseShellExecute = $false
    $procInfo.Arguments = "/dsgetdc:$domain"
    
    # Start the process
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $procInfo
    $proc.Start() | Out-Null
    $proc.WaitForExit()

    # Retrieve the results
    $out = $proc.StandardOutput.ReadToEnd()
    $err = $proc.StandardError.ReadToEnd()

    If ($err) { Return $null }

    # Fix the results
    $destination = (($out -Split '\n')[0].Trim() -Split ": ")[1] -Replace "\\"

    # Figure out how we're connecting to it (if we even are)
    # and prepare to return that information
    $connection = Test-NetConnection -ComputerName $destination -DiagnoseRouting

    # Check if the connection worked or not and then return the
    # IP of the local adapter being used
    If ($connection.RouteDiagnosticsSucceeded) {
        $result = New-Object System.Collections.ArrayList
        $temp = [PsCustomObject]@{
            Name = $connection.ComputerName
            Address = $connection.SelectedSourceAddress.IpAddress
            Domain = $domain
        }
        $result.Add($temp) | Out-Null
        Return $result
    }
    Else {
        Return $null
    }

}

# A function for checking mSSMS Boundary groups and doing comparisons
Function Get-SMSBoundaryInformation {
    Param ([IpAddress]$ip,$dc,$domain)

    # Convert an IP Address into decimal notation
    $bytes = $ip.GetAddressBytes()

    If ([BitConverter]::IsLittleEndian) {
        [Array]::Reverse($bytes)
    }

    $compare = [BitConverter]::ToUInt32($bytes, 0)

    # Format a FQDN
    $distinguishedName = "dc=" + $domain.Replace(".",",dc=")

    # Lookup all the boundary ranges in AD
    $directoryDomain = [System.DirectoryServices.DirectoryEntry]::("LDAP://$dc/$distinguishedName")
    $directorySearcher = [System.DirectoryServices.DirectorySearcher]::new($directoryDomain)
    $directorySearcher.Filter = "(objectCategory=msSMSRoamingBoundaryRange)"
    $result = ($directorySearcher.FindAll()).Properties

    # Convert the results into a more manageable table
    $boundaryTable = [System.Collections.ArrayList]::new()

    For ($i=0;$i -lt $result.Count;$i++) {
        $temp = $result[$i]
        $boundaryTable.Add([PsCustomObject]@{
            Name     = $temp.name
            SiteCode = $temp.mssmssitecode
            Start    = $temp.mssmsrangediplow
            End      = $temp.mssmsrangediphigh
        }) | Out-Null
    }

    # Finally, do a quick lookup of where the IP would live
    Return $boundaryTable.Where{(($_.Start -le $compare) -and ($_.End -ge $compare))}

}

# Check AD for the default Management point based on assumed sitecode
Function Get-SMSDefaultMP {
    Param ($check)
    
    # First, we need to get all the management points from AD
    $directorySearcher = [System.DirectoryServices.DirectorySearcher]::new()
    $directorySearcher.Filter = "(objectCategory=msSMSManagementPoint)"
    $result = ($directorySearcher.FindAll()).Properties
        
    # Now, we throw all of that information into a more manageable table
    $managementPointTable = [System.Collections.ArrayList]::new()
    
    For ($i=0;$i -lt $result.Count;$i++) {
        $temp = $result[$i]
        $managementPointTable.Add([PsCustomObject]@{
            Name      = $temp.mssmsmpname
            SiteCode  = $temp.mssmssitecode
            IsDefault = $temp.mssmsdefaultmp
        }) | Out-Null
    }

    # We only want the default MPs so let's sort it down
    $defaultMPTable = $managementPointTable.Where{$_.IsDefault -eq $true}

    # With any luck, the client only belongs to one site
    # but if not, we need to account for that...
    If ($check.SiteCode.Count -gt 1) {
        # You can have multiple sites but you can't have overlapping boundaries
        # If you have overlapping boundaries with active sites, go fix your stuff!
        # We're going to go with the first site that's serving IIS
        ForEach ($site in $check.SiteCode) {
            $MPCheck = $defaultMPTable.Where{$_.SiteCode -eq $site}

            ForEach ($managementPoint in $MPCheck) {
                Try {
                    $iisCheck = Invoke-WebRequest -Uri ([string]$managementPoint.Name) -UseBasicParsing -ErrorAction Stop
                }
                Catch {
                    Continue
                }

                If ($iisCheck.StatusCode -eq 200) {
                    $connectingMP = [PsCustomObject]@{
                        Name = $managementPoint.Name
                        SiteCode = $managementPoint.SiteCode
                    }
                    Break
                }
            }

            If ($connectingMP) { Break }
        }
    }
    Else {
        $connectingMP = $defaultMPTable.Where{$_.SiteCode -eq $site}
    }

    If ($connectingMP) {
        Return $connectingMP
    }
    Else {
        Return $null
    }

}

# Check to see if HTTPS is on
# If https is being used, the function will return the cert needed to
# communicate with the site
Function Get-CommunicationCertificate {
    Param($address)

    # Will use the ccm client page
    If ($address -match "ccm_client") {
        $uri = $address
    }
    Else {
        $uri = "$address/CCM_Client"
    }

    # initial check
    Try { 
        $result = (Invoke-WebRequest -Uri $uri -UseBasicParsing -ErrorAction Stop).StatusDescription
    }
    Catch {
        $result = $_.Exception.Status
    }

    # Choose a condition
    Switch ($result) {
        'TrustFailure' {
            # the assumption is that https isn't on and ssl/tls isn't trusted
            # do the same as 'advanced > proceed anyways'
            add-type '
                using System.Net;
                using System.Security.Cryptography.X509Certificates;
                public class TrustAllCertsPolicy : ICertificatePolicy {
                    public bool CheckValidationResult(
                        ServicePoint srvPoint, X509Certificate certificate,
                        WebRequest request, int certificateProblem) {
                        return true;
                    }
                }
            '

            $AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
            [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
            [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

            $authCertificate = "Plaintext"
        }
        
        'ProtocolError' {
            # https is setup but you need a certificate
            # We need to thumb through machine certs to find the correct one
            $certs = (Get-ChildItem -Path Cert:\LocalMachine\My).Where{$_.EnhancedKeyUsageList -like "Client Auth*"}
            
            If ($uri -notmatch 'https://') {
                $uri = "https://" + ($uri -Split "://")[1]
            }
            
            ForEach ($cert in $certs) {
                Try {
                    $request = Invoke-WebRequest -Uri "$uri" -UseBasicParsing -Certificate $cert -ErrorAction Stop
                }
                Catch {
                    $_.Exception.Message | Out-Null
                }

                If ($request.StatusCode -eq 200) {
                    $authCertificate = $cert
                    Break
                }
            }

        }

        'OK' {
            $authCertificate = "Plaintext"
        }

    }

    Return ,$authCertificate

}

# Invoke ccmsetup from whatever source is determined
Function Install-CcmClient {
    Param (
        [Parameter(Mandatory=$true)]$source,
        $certificate,
        $site
    )
            
    Begin {
        $tmp = "C:\Temp"
        $mp = ($source -Split "/")[2]
        $parentDir = "$source/CCM_CLIENT/"
        $directories = [System.Collections.ArrayList]::new()  
    }

    Process {
        If (-Not(Test-Path $tmp)) {
            New-Item -Path $tmp -ItemType Directory -Force | Out-Null
        }

        # start with the top level directory when processing
        $directories.Add($parentDir) | Out-Null

        # If certificate is specified, yoink the download folder using a cert
        For($i=0;$i -lt $directories.Count;$i++) {
            # smoosh the temp path together with the end segment of the current
            # directory selected from the collection
            $destination = $tmp + ($directories[$i] -Replace $source -Replace "\/","\")

            # Create the new directory
            If (-Not(Test-Path -Path $destination)) {
                Write-Log -Message "Creating $destination" -Component "InstallStatus" -Type 1 
                New-Item -Path $destination -ItemType Directory -Force | Out-Null
            }

            # Wait for the directory before you try stuffing things into it
            While (-Not(Test-Path -Path $destination)) { Start-Sleep -Milliseconds 100 }

            If ($certificate) {
                $content = Invoke-WebRequest -Uri $directories[$i] -UseBasicParsing -TimeoutSec 300 -Certificate $certificate
            }
            Else {
                $content = Invoke-WebRequest -Uri $directories[$i] -UseBasicParsing -TimeoutSec 300
            }

            $links = $content.Links.HREF

            # we skip the first index because it's the parent dir
            For($n=1;$n -lt $links.Count;$n++) {
                $link = $links[$n]

                # if there's a trailing /, it's a directory
                If ($link -match "\/$") {
                    $add = $source + $link
                    $directories.Add($add) | Out-Null
                }
                Else {
                    $parentDir = $source + $link
                    $childDir = ($destination -Replace [regex]::Escape($tmp)).TrimStart("\")
                    $item = $tmp + ($link -Replace [regex]::Escape($childDir) -Replace "\/","\")
                    $ProgressPreference = 'SilentlyContinue'

                    Write-Log -Message "Downloading $($link -Replace [regex]::Escape($childDir) -Replace "\/","\")" -Component "InstallStatus" -Type 1 
                    If ($certificate) {
                        Invoke-WebRequest -Uri $parentDir -UseBasicParsing -TimeoutSec 300 -Certificate $certificate -OutFile $item
                    }
                    Else {
                        Invoke-WebRequest -Uri $parentDir -UseBasicParsing -TimeoutSec 300 -OutFile $item
                    }
                }

                If ($link -match "ccmsetup.exe") {
                    $exe = $tmp + ($link -Replace [regex]::Escape($childDir) -Replace "\/","\")
                }
            }                  
        }

        If (-Not(Test-Path $exe)) {
            # The exe doesn't exist and we can't install...
            Exit 1
        }

        # The exe copied over successfully and we CAN install!
        # We need to do yet another cert check to dictate install switches
        Write-Log -Message "Starting installation process..." -Component "InstallStatus" -Type 1 
        If ($certificate) {
            # SiteCode doesn't need to be stipulated if MP is specified

            Start-Process $exe -ArgumentList "CCMHOSTNAME=$source SMSMP=$mp SMSSITECODE=$site /NOCRLCHECK /USEPKICERT" -Wait
        }
        Else {
            Start-Process $exe -ArgumentList "CCMHOSTNAME=$source SMSMP=$mp SMSSITECODE=$site /NOCRLCHECK" -Wait
        }

        # And now we wait for it to install
        $ccmsetupDir = "$($env:windir)\ccmsetup"

        Do {
            If (-Not(Test-Path -Path $ccmsetupDir)) {
                Start-Sleep -Milliseconds 500
            }
            ElseIf (-Not(Test-Path -Path "$ccmsetupDir\Logs")) {
                Start-Sleep -Milliseconds 500
            }
            Else {
                $log = Get-Content -Path "$ccmsetupDir\Logs\ccmsetup.log" -Tail 1

                If ($log -notlike "*CcmSetup is exiting with return code*") {
                    Start-Sleep -Milliseconds 500
                }
                ElseIf ($log -like "*CcmSetup failed*") {
                    $done = $true
                }
                Else {
                    $done = $true
                }
            }
        } Until ($done)
    }

    End {
        Remove-Item -Path "$tmp\CCM_Client" -Recurse -Force
        Return $log
    }

}

# Uninstall the ccm client
Function Uninstall-CcmClient {

    $client = Get-Service -Name CcmExec -ErrorAction SilentlyContinue
    If ($client) { 
        Stop-Service -Name $client.Name -Force -Confirm:$false
        Get-Process -Name WmiPrvSE -IncludeUserName | ForEach-Object {If ($_.Username -match 'SYSTEM') {Stop-Process -Name $_.Name -Force}}
    }

    $ccmSetupPath = "$($env:windir)\ccmsetup"

    If (-Not(Test-Path -Path $ccmSetupPath)) {
        #lolwut
        # Client is installed but the ability to remove it is non-existent
        # Time to take matters into our own hands!
        $ccm = List-InstalledApps -AppName "Configuration Manager"

        If ($ccm) {
            If (-Not($ccm.Uninstall)) {
                Start-Process msiexec -ArgumentList "/x $($ccm.MsiCode) /qn /norestart" -Wait
            }
            Else {
                $uninstall = $app.Uninstall -Split "(?=\s/)"
                $exe = $uninstall[0]

                If ($app.Uninstall -match "msiexec") {
                    $arg = "$($uninstall[1]) /qn /norestart"
                }
                Else {
                    $arg = "$($uninstall[1])"
                }

                If ($arg -match 'uninstall') {
                    $arg = '/r'
                }

                Start-Process $exe -ArgumentList $arg -Wait
            }
        }
        Else {
            # There's a client but there's no way of removing it
            # Just gonna hafta best-effort it
        }
    }
    Else {
        Start-Process "$ccmSetupPath\ccmsetup.exe" -ArgumentList "/uninstall" -Wait

        Do {
            $log = Get-Content -Path "$ccmSetupPath\Logs\ccmsetup.log" -Tail 1

            If ($log -notlike "*CcmSetup is exiting with return code*") {
                Start-Sleep -Seconds 30
            }
            Else {
                $done = $true
            }
        } Until ($done)
    }

    # Final Cleanup
    If (Test-Path -Path "$($env:windir)\ccm") {
        Do {
            Try {
                Remove-Item -Path "$($env:windir)\ccm" -Recurse -Force -ErrorAction Stop
                $done = $true
            }
            Catch {
                Start-Sleep -Milliseconds 100
            }
        } Until ($done)

        $done = $null
    }

    If (Test-Path -Path $ccmSetupPath) {
        Remove-Item -Path $ccmSetupPath -Recurse -Force
    }

}

# Check certain services and make sure they're configured properly
Function Set-ServiceConfigAndState {
    Param ($services)

    Begin {
        # Reg Path for services (needed for looking up DelayedAutostart)
        $root = "HKLM:\SYSTEM\CurrentControlSet\Services"
    }

    Process {
        # Check all the services
        ForEach ($service in $services.Keys) {
            # Lookup the service
            $config = Get-WmiObject -Class win32_service -Filter "Name='$service'" 

            # Does it have a DelayedStart config?
            Try {
                $delay = (Get-ItemProperty -Path "$root\$service" -Name "DelayedAutostart" -ErrorAction Stop).DelayedAutostart
            }
            Catch {
                $delay = 0
            }

            If ($delay -eq 1) {
                $check = ("delayed-$($config.StartMode)").ToLower()
            }
            Else {
                $check = ($config.StartMode).ToLower()
            }

            # Make sure the startup type for the service is set properly
            If ($check -notmatch $($services[$service])) {
                Write-Log -Message "$($service) configured as $($check) instead of $($services[$service]). Adjusting..." -Component ConfigureServices -Type 2
                Start-Process sc.exe -ArgumentList "config $service start= $($services[$service])" -Wait
            }

            # Is the service currently running? It'd better be!
            If ($config.State -ne 'Running') {
                Write-Log -Message "$($service) is not running. Starting..." -Component ConfigureServices -Type 2
                Start-Service -Name $service
            }

        }
    }

    End {
        # nothing to dispose
        Return
    }

}
                    
        
########################### GATHER INFORMATION #############################
Write-Log -Message "Checking network adapter" -Component "GatherInfo" -Type 1 -Header
 
# Start by wiping the DNS cache
Clear-DnsClientCache

# Is the network connected?
$connectedAdapter = Get-WmiObject -Class win32_NetworkAdapter -Filter "netconnectionstatus=2"

If ($connectedAdapter) {
    # Is there even Internet?
    $internetTest = Test-NetConnection -ComputerName 8.8.8.8
    
    If (!$internetTest) {
        # We gots no Internet!
        Write-Log -Message "Could not connect to the Internet. Exiting..." -Component "GatherInfo" -Type 2
        Exit 1
    }
}
Else {
    # Thing ain't even plugged in
    Write-Log -Message "No network adapter connected. Exiting..." -Component "GatherInfo" -Type 2
    Exit 1
}
  
# Are we using on-prem resources or connecting to a CMG?
# First, let's gather information from the domain to determine
# which MP to install from. If the domain isn't available
# we'll default to the CMG
Write-Log -Message "Checking for connection to Active Directory" -Component "Get-ADConnectionInformation" -Type 1
$adConnectionAddress = Get-ADConnectionInformation

If ($adConnectionAddress) {
    Write-Log -Message "Found connection to $($adConnectionAddress.Name), $($adconnectionAddress.Address)" -Component "Get-ADConnectionInformation" -Type 1
    Write-Log -Message "Checking $($adConnectionAddress.Name) for SMS information" -Component "Get-SMSBoundaryInformation" -Type 1

    # AD is available so we'll try and find an MP from here
    $boundaryInfo = Get-SMSBoundaryInformation -IP $adConnectionAddress.Address -DC $adConnectionAddress.Name -Domain $adConnectionAddress.Domain

    If ($boundaryInfo) {
        If ($boundaryInfo.Name.Count -gt 1) {
            Write-Log -Message "Found multiple boundaries" -Component "Get-SMSBoundaryInformation" -Type 2
        }
        Else {
            Write-Log -Message "Endpoint belongs to $($boundaryInfo.Name)" -Component "Get-SMSBoundaryInformation" -Type 1
        }

        Write-Log -Message "Trying to detmine the default Management Point" -Component "Get-SMSBoundaryInformation" -Type 1

        # There's info in AD about which boundary/site the client should belong to
        # Try to figure out which MP to communicate with
        $defaultMP = Get-SMSDefaultMP -Check $boundaryInfo
        
        If ($defaultMP) {
            Write-Log -Message "Default Management Point is $($defaultMP.Name)" -Component "Get-SMSDefaultMP" -Type 1

            # Last embedded if, promise! Check to see if the MP requires https
            Write-Log -Message "Checking for HTTPS on the Management Point" -Component "Get-CommunicationCertificate" -Type 1
            $authCertificate = Get-CommunicationCertificate -Address $defaultMP.Name
        }
        Else {
            Write-Log -Message "Could not locate a default Management Point" -Component "Get-SMSDefaultMP" -Type 2
            $useCMG = $true
        }
    }
    Else {
        Write-Log -Message "Could not determine Site Code or Boundary information" -Component "Get-SMSBoundaryInformation" -Type 2
        $useCMG = $true
    }
}
Else {
    Write-Log -Message "Could not find connection to Active Directory" -Component "Get-ADConnectionInformation" -Type 2
    
    If ($CMG) {
        $useCMG = $true
    }
}

If ((!$CMG) -and (!$useCMG)) {
    Write-Log -Message "Could not find connection to Active Directory and no Cloud Management Gateway was specified" -Component "GatherInfo" -Type 3
    Write-Log -Message "Exiting with Code: 1" -Component "GatherInfo" -Type 1
    Exit 1
}

# Now to put all the computed information into a single, neat object
If ($useCMG) {
    Write-Log -Message "Defaulting to Cloud Management Gateway, $($CMG)" -Component "GatherInfo" -Type 1

    # Couldn't contact or gather on-prem resources properly so use the CMG
    # The CMG uses https but we still need to run the function to test it to get the cert
    If ($CMG -notlike '*CCM_Proxy_MutualAuth*') {
        Write-Log -Message "Address specified is not a Cloud Management Gateway." -Component "GatherInfo" -Type 2
        Exit 1
    }
    $authCertificate = Get-CommunicationCertificate -Address $CMG

    If (!$authCertificate) {
        Write-Log -Message "Could not communicate with the specified CMG." -Component "GatherInfo" -Type 2
        Exit 1
    }
    ElseIf ($authCertificate -match "Plaintext") {
        # Get the site code from the CMG
        [xml]$content = (Invoke-WebRequest -Uri "$CMG/sms_mp/.sms_aut?MPKEYINFORMATION" -UseBasicParsing).Content
    }
    Else {
        # Get the site code from the CMG
        [xml]$content = (Invoke-WebRequest -Uri "$CMG/sms_mp/.sms_aut?MPKEYINFORMATION" -UseBasicParsing -Certificate $authCertificate).Content
    }
    
    # Declare the output table
    $connectionInfo = [PsCustomObject]@{
        DefaultMP = $CMG
        SiteCode  = $content.MPKEYINFORMATION.SITECODE
    }
}
Else {
    $connectionInfo = [PsCustomObject]@{
        DefaultMP = $defaultMP.Name
        SiteCode  = $defaultMP.SiteCode
    }
}

############################################################################


##################### CHECK IF CLIENT IS INSTALLED #########################
Write-Log -Message "Checking client installation status" -Component "InstallStatus" -Type 1

# Is the ConfigMgr client installed?
$clientCheck = List-InstalledApps -AppName 'Configuration Manager Client'

# But like, is it really?
$secondClientCheck = (Get-WmiObject -Namespace root -Class __NAMESPACE).Where{$_.Name -eq 'ccm'}

If (-Not($clientCheck -and $secondClientCheck)) {
    Write-Log -Message "No CCM Client installed. Attempting to install" -Component "InstallStatus" -Type 2

    # Didn't find the client so let's install it
    If ($authCertificate) {
        Write-Log -Message "Connecting to $($connectionInfo.DefaultMP) using HTTPS" -Component "InstallStatus" -Type 1   
        $install = Install-CcmClient -Source "$($connectionInfo.DefaultMP)" -Site $connectionInfo.SiteCode -Certificate $authCertificate
    }
    Else {
        Write-Log -Message "Connecting to $($connectionInfo.DefaultMP) using Plaintext" -Component "InstallStatus" -Type 1 
        $install = Install-CcmClient -Source $connectionInfo.DefaultMP -Site $connectionInfo.SiteCode
    }

    Write-Log -Message $install -Component "InstallStatus" -Type 1
}
Else {
    Write-Log -Message "Client is installed." -Component "InstallStatus" -Type 1
}

############################################################################


################### CHECK WHAT SITE THE CLIENT IS IN #######################
Write-Log -Message "Checking client site assignment" -Component "AssignmentStatus" -Type 1

$client = New-Object -ComObject 'Microsoft.SMS.Client'
$assignedSite = $client.GetAssignedSite()

If ($assignedSite -ne $connectionInfo.SiteCode) {
    Write-Log -Message "Client was assigned to $($assignedSite)." -Component "AssignmentStatus" -Type 2
    Write-Log -Message "Attempting to assign client to $($connectionInfo.SiteCode)" -Component "AssignmentStatus" -Type 1

    For ($i=1;$i -lt 4;$i++) {
        # Since a COM Method can't be put in a try/catch, we'll try to set the code
        # three times before failing out
        $client.SetAssignedSite($connectionInfo.SiteCode,0)
        $assignedSite = $client.GetAssignedSite()

        If ($assignedSite -ne $connectionInfo.SiteCode) {
            Write-Log -Message "Attempt $i of 3 failed. Trying again" -Component "AssignmentStatus" -Type 2
            $changed = $false
        }
        Else {
            Write-Log -Message "Site successfully assigned in $i of 3 times." -Component "AssignmentStatus" -Type 1
            Break
        }
    }

    If ($changed -eq $false) {
        Write-Log -Message "Was not able to assign proper Site Code" -Component "AssignmentStatus" -Type 3
        Write-Log -Message "Uninstalling and reinstalling client" -Component "AssignmentStatus" -Type 1
        Uninstall-CcmClient
        Start-Sleep -Seconds 5 #This is just for posterity's sake
        # Didn't find the client so let's install it
        If ($authCertificate) {
            Write-Log -Message "Connecting to $($connectionInfo.DefaultMP) using HTTPS" -Component "InstallStatus" -Type 1   
            $install = Install-CcmClient -Source $connectionInfo.DefaultMP -Site $connectionInfo.SiteCode -Certificate $authCertificate
        }
        Else {
            Write-Log -Message "Connecting to $($connectionInfo.DefaultMP) using Plaintext" -Component "InstallStatus" -Type 1 
            $install = Install-CcmClient -Source $connectionInfo.DefaultMP -Site $connectionInfo.SiteCode
        }

        Write-Log -Message $install -Component "InstallStatus" -Type 1
    }
            
}
Else {
    Write-Log -Message "Client is assigned to correct site: $($assignedSite)" -Component "AssignmentStatus" -Type 1
}

############################################################################


################## WHERE APPLICABLE: ADD CMG CAPABILITIES ##################
If ($CMG) {
    Write-Log -Message "Cloud Management Gateway specified. Checking if information is already available to client" -Component "CmgStatus" -Type 1

    $client = New-Object -ComObject 'Microsoft.SMS.Client'
    $mpFQDN = $client.GetInternetManagementPointFQDN()

    If ($CMG -notmatch $mpFQDN) {
        Write-Log -Message "Client was assigned to a different CMG: $($mpFQDN)" -Component "CmgStatus" -Type 2

        For ($i=1;$i -lt 4;$i++) {
            $client.SetInternetManagementPointFQDN($CMG)
            $mpFQDN = $client.GetInternetManagementPointFQDN()

            If ($mpFQDN -ne $CMG) {
                Write-Log -Message "Attempt $i or 3 failed. Trying again" -Component "CmgStatus" -Type 2
                $changed = $false
            }
            Else {
                Write-Log -Message "CMG successfully assigned in $i of 3 times." -Component "CmgStatus" -Type 1
                Break
            }
        }

        If ($changed -eq $false) {
            Write-Log -Message "Was not able to assign CMG" -Component "CmgStatus" -Type 3
        }
    }
    Else {
        Write-Log -Message "Client is assigned to correct CMG: $($mpFQDN)" -Component "CmgStatus" -Type 1
    }

}

############################################################################


######################### CHECK CLIENT VERSION #############################
Write-Log -Message "Checking client version" -Component "VersionStatus" -Type 1
$uri = "$($connectionInfo.DefaultMP)/sms_mp/.sms_aut?mplist"

If ($authCertificate) {
    [xml]$content = Invoke-WebRequest -uri $uri -UseBasicParsing -Certificate $authCertificate
}
Else {
    [xml]$content = Invoke-WebRequest -uri $uri -UseBasicParsing
}

$serverVersion = $content.MPList.MP.Version
$clientVersion = (Get-WmiObject -Namespace root\ccm -Class SMS_Client).ClientVersion

# If it doesn't have the right client version, we'll hafta uninstall/reinstall
If ($clientVersion -notmatch $serverVersion) {
    Write-Log -Message "Client version $($clientVersion) did not match server version $($serverVersion)" -Component "VersionStatus" -Type 2
    Write-Log -Message "Uninstalling and reinstalling client" -Component "VersionStatus" -Type 1
    Uninstall-CcmClient
    Start-Sleep -Seconds 5 #This is just for posterity's sake
    # Didn't find the client so let's install it
    If ($authCertificate) {
        Write-Log -Message "Connecting to $($connectionInfo.DefaultMP) using HTTPS" -Component "InstallStatus" -Type 1   
        $install = Install-CcmClient -Source $connectionInfo.DefaultMP -Certificate $authCertificate
    }
    Else {
        Write-Log -Message "Connecting to $($connectionInfo.DefaultMP) using Plaintext" -Component "InstallStatus" -Type 1 
        $install = Install-CcmClient -Source $connectionInfo.DefaultMP
    }

    Write-Log -Message $install -Component "InstallStatus" -Type 1
}
Else {
    Write-Log -Message "Client version is correct: $($clientVersion)" -Component "VersionStatus" -Type 1
}
############################################################################


########################### CHECK SERVICES #################################
Write-Log -Message "Checking key services." -Component ConfigureServices -Type 1
Set-ServiceConfigAndState -Services $services
Write-Log -Message "Services all set." -Component ConfigureServices -Type 1
############################################################################

}


$root = "$($env:ProgramData)\CcmHealth"

If (-Not(Test-Path $root)) {
    New-Item -Path $env:ProgramData -Name 'CcmHealth' -ItemType Directory
    $script | Out-File "$($root)\health.ps1" -Encoding utf8 -Width 4096 -Force
}
Else {
    $script | Out-File "$($root)\health.ps1" -Encoding utf8 -Width 4096 -Force
}

# What is the scheduled task going to do?
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument `
"-ExecutionPolicy Bypass $root\health.ps1 -cmg $cmg"

# When is it going to do it?
$class = Get-CimClass -Namespace root/Microsoft/Windows/TaskScheduler -ClassName MSFT_TaskEventTrigger
$trigger = $class | New-CimInstance -ClientOnly
$trigger.Enabled = $true
$trigger.Subscription = @"
<QueryList>
    <Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational">
        <Select Path="Microsoft-Windows-NetworkProfile/Operational">
            *[System[Provider[@Name='Microsoft-Windows-NetworkProfile'] and EventID=4004]]
        </Select>
    </Query>
</QueryList>
"@
$trigger.Delay = 'PT30S'

# Additional settings
$settings = New-ScheduledTaskSettingsSet

# Who's going to run this?
$principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount

# Name the task and put in final properties
$parameters = @{
    TaskName    = 'Ccm Health Check'
    Description = 'Check for MECM client anomalies and attempt to repair.'
    TaskPath    = '\'
    Action      = $action
    Principal   = $principal
    Settings    = $settings
    Trigger     = $trigger
}

# Register the task
Register-ScheduledTask @parameters
