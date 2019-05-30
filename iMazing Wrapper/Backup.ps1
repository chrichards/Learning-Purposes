# iMazing utility location
$script:imazing = "$env:ProgramFiles\DigiDNA\iMazing-CLI\iMazing-CLI.exe"
$script:ours = "SomePassword"
$script:share = '\\server\backups$'

# Enable WPF
Add-Type -AssemblyName PresentationCore,PresentationFramework

# Make sure this is the only instance running
$process = get-process '<Company> iOS Archive Utility' -erroraction silentlycontinue
if($process.Count -gt 1){
    $button = [System.Windows.MessageBoxButton]::OK
    $icon = [System.Windows.MessageBoxImage]::Information
    $body = "The iOS archive utility is already running."
    $title = "<Company> iOS Archive Utility"
 
    [System.Windows.MessageBox]::Show($body,$title,$button,$icon)
    Exit
}

# Begin function blocks
Function Get-Segment {
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("prompt", "process")]
        [string]$mode,

        [Parameter(Mandatory=$true)]
        [int]$type
    )

    # Reset the button results
    $dialog_result = $null

    # What type of display is being fetched
    Switch ($mode) {
        'prompt' {
            Switch ($type) {
                1 {
                    [xml]$msg = '
                    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
                        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Window"
                        Title="<Company> iOS Archive Utility" Height="250" Width="270" ShowInTaskbar="True"
                        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
                        <Canvas>
                            <TextBlock Name="Text1" Canvas.Left="15" Canvas.Top="40" Width="225" Height="75" TextWrapping="Wrap">
                                You are about to run the <Company> iOS archive utility.<LineBreak/>
                                <LineBreak/>
                                Note: This process can take up to 2 hours
                            </TextBlock>
                            <Button x:Name="Button1" Content="Continue" Canvas.Left="25" Canvas.Top="162" Width="75" Height="23" FontWeight="Bold"/>
                            <Button x:Name="Button2" Content="Quit" Canvas.Left="150" Canvas.Top="162" Width="75" Height="23" FontWeight="Bold"/>
                        </Canvas>
                    </Window>
                    '
                    $button = 2
                }

                2 {
                    [xml]$msg = '
                    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
                        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Window"
                        Title="<Company> iOS Archive Utility" Height="250" Width="270" ShowInTaskbar="True"
                        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
                        <Canvas>
                            <TextBlock Name="Text1" Canvas.Left="15" Canvas.Top="15" Width="225" Height="130" TextWrapping="Wrap">
                                Could not find a device to backup. Please check the cable connection to
                                your PC and to your device.<LineBreak/>
                                <LineBreak/>
                                Also, please make sure that your device is unlocked. If it is asking you
                                to trust your PC, please tap to accept.
                            </TextBlock>
                            <Button x:Name="Button1" Content="Retry" Canvas.Left="25" Canvas.Top="162" Width="75" Height="23" FontWeight="Bold"/>
                            <Button x:Name="Button2" Content="Quit" Canvas.Left="150" Canvas.Top="162" Width="75" Height="23" FontWeight="Bold"/>
                        </Canvas>
                    </Window>
                    '
                    $button = 2
                }

                3 {
                    [xml]$msg = '
                    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
                        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Window"
                        Title="<Company> iOS Archive Utility" Height="250" Width="270" ShowInTaskbar="True"
                        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
                        <Canvas>
                            <TextBlock Name="Text1" Canvas.Left="15" Canvas.Top="15" Width="225" Height="150" TextWrapping="Wrap">
                                Could not find or connect to your device.<LineBreak/>
                                <LineBreak/>
                                Troubleshooting tips:<LineBreak/>
                                - Use an Apple specific USB cable<LineBreak/>
                                - Unlock and check your device for notifications or prompts to trust<LineBreak/>
                                - Restart your computer
                            </TextBlock>
                            <Button x:Name="Button1" Content="OK" Canvas.Left="87.5" Canvas.Top="162" Width="75" Height="23" FontWeight="Bold"/>
                        </Canvas>
                    </Window>
                    '
                    $button = 1
                }

                4 {
                    [xml]$msg = '
                    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
                        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Window"
                        Title="<Company> iOS Archive Utility" Height="250" Width="270" ShowInTaskbar="True"
                        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
                        <Canvas>
                            <TextBlock Name="Text1" Canvas.Left="15" Canvas.Top="15" Width="225" Height="150" TextWrapping="Wrap">
                                Could not gather information from your device.
                                Unlock your device and check for a "Trust this computer?" message.
                                After selecting "Trust" on your device, click Retry on this utility.
                            </TextBlock>
                            <Button x:Name="Button1" Content="Retry" Canvas.Left="25" Canvas.Top="162" Width="75" Height="23" FontWeight="Bold"/>
                            <Button x:Name="Button2" Content="Quit" Canvas.Left="150" Canvas.Top="162" Width="75" Height="23" FontWeight="Bold"/>
                        </Canvas>
                    </Window>
                    '
                    $button = 2
                }

                5 {
                    [xml]$msg = '
                    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
                        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Window"
                        Title="<Company> iOS Archive Utility" Height="350" Width="300" ShowInTaskbar="True"
                        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
                        <Canvas>
                            <TextBlock Name="Text1" Canvas.Left="15" Canvas.Top="15" Width="250" Height="250" TextWrapping="Wrap">
                                Your iOS version does not meet the minimum requirement for running this utility.
                                Please disconnect your device and perform a system update.<LineBreak/>
                                <LineBreak/>
                                On your device, complete the following:<LineBreak/>
                                - Connect to a Wi-Fi network<LineBreak/>
                                - Open "Settings"<LineBreak/>
                                - Go to "General" and tap "Software Update"<LineBreak/>
                                - In "Software Update," tap "Download and Install"<LineBreak/>
                                - Once the update is complete, plug your device back into your computer, and re-run
                                this backup utility
                            </TextBlock>
                            <Button x:Name="Button1" Content="OK" Canvas.Left="100.5" Canvas.Top="272" Width="75" Height="23" FontWeight="Bold"/>
                        </Canvas>
                    </Window>
                    '
                    $button = 1
                }

                6 {
                    [xml]$msg = '
                    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
                        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Window"
                        Title="<Company> iOS Archive Utility" Height="250" Width="270" ShowInTaskbar="True"
                        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
                        <Canvas FocusManager.FocusedElement="{Binding ElementName=PwdBox}">
                            <TextBlock Name="Text1" Canvas.Left="15" Canvas.Top="15" Width="225" Height="95" TextWrapping="Wrap">
                                An existing device backup password is set. Please enter the password to continue.<LineBreak/>
                                <LineBreak/>
                                Backup Password:
                            </TextBlock>
                            <PasswordBox x:Name="PwdBox" Canvas.Left="15" Canvas.Top="100" Width="225" Height="20"/>
                            <Button x:Name="Button1" Content="OK" Canvas.Left="25" Canvas.Top="162" Width="75" Height="23" FontWeight="Bold"/>
                            <Button x:Name="Button2" Content="Cancel" Canvas.Left="150" Canvas.Top="162" Width="75" Height="23" FontWeight="Bold"/>
                        </Canvas>
                    </Window>
                    '
                    $button = 2
                    $pwdbox = $true
                }

                7 {
                    [xml]$msg = '
                    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
                        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Window"
                        Title="<Company> iOS Archive Utility" Height="250" Width="270" ShowInTaskbar="True"
                        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
                        <Canvas>
                            <TextBlock Name="Text1" Canvas.Left="15" Canvas.Top="30" Width="225" Height="95" TextWrapping="Wrap">
                                Your backup password was incorrect. Please try again.<LineBreak/>
                                <LineBreak/>
                                Hint: You may have previously used this password to backup this device with iTunes.
                            </TextBlock>
                            <Button x:Name="Button1" Content="Retry" Canvas.Left="25" Canvas.Top="162" Width="75" Height="23" FontWeight="Bold"/>
                            <Button x:Name="Button2" Content="Quit" Canvas.Left="150" Canvas.Top="162" Width="75" Height="23" FontWeight="Bold"/>
                        </Canvas>
                    </Window>
                    '
                    $button = 2
                }

                8 {
                    [xml]$msg = '
                    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
                        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Window"
                        Title="<Company> iOS Archive Utility" Height="350" Width="300" ShowInTaskbar="True"
                        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
                        <Canvas>
                            <TextBlock Name="Text1" Canvas.Left="15" Canvas.Top="15" Width="250" Height="250" TextWrapping="Wrap">
                                Please perform the following before continuing with the backup process:<LineBreak/>
                                <LineBreak/>
                                - Unplug your device from your PC<LineBreak/>
                                - Unlock your device<LineBreak/>
                                - Open "Settings"<LineBreak/>
                                - In "Settings," select "General"<LineBreak/>
                                - At the bottom, select "Reset"<LineBreak/>
                                - Select "Reset all settings"<LineBreak/>
                                - Confirm the reset twice<LineBreak/>
                                - Your device will reboot<LineBreak/>
                                - Once your device reboots, plug it back into your PC
                                and re-run this backup utility
                            </TextBlock>
                            <Button x:Name="Button1" Content="OK" Canvas.Left="100.5" Canvas.Top="272" Width="75" Height="23" FontWeight="Bold"/>
                        </Canvas>
                    </Window>
                    '
                    $button = 1
                }

                9 {
                    [xml]$msg = '
                    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
                        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Window"
                        Title="<Company> iOS Archive Utility" Height="250" Width="270" ShowInTaskbar="True"
                        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
                        <Canvas>
                            <TextBlock Name="Text1" Canvas.Left="15" Canvas.Top="15" Width="225" Height="150" TextWrapping="Wrap">
                                Backup complete! You may now unplug your device.
                            </TextBlock>
                            <Button x:Name="Button1" Content="OK" Canvas.Left="87.5" Canvas.Top="162" Width="75" Height="23" FontWeight="Bold"/>
                        </Canvas>
                    </Window>
                    '
                    $button = 1
                }

                10 {
                    [xml]$msg = '
                    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
                        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Window"
                        Title="<Company> iOS Archive Utility" Height="250" Width="270" ShowInTaskbar="True"
                        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
                        <Canvas>
                            <TextBlock Name="Text1" Canvas.Left="15" Canvas.Top="15" Width="225" Height="150" TextWrapping="Wrap">
                                Something went wrong during the backup process.
                                Please disconnect your device then try again.<LineBreak/>
                                <LineBreak/>
                                If the backup fails again, please contact the IT Helpdesk (ITHelpdesk@company.com)
                                (555) 555-5555.
                            </TextBlock>
                            <Button x:Name="Button1" Content="OK" Canvas.Left="87.5" Canvas.Top="162" Width="75" Height="23" FontWeight="Bold"/>
                        </Canvas>
                    </Window>
                    '
                    $button = 1
                }
            }

            # Window Constructor
            $reader = New-Object System.Xml.XmlNodeReader $msg
            $window = [Windows.Markup.XamlReader]::Load($reader)

            # Declare the user input password
            If($pwdbox -eq $true){
                $pwdobj = $window.FindName("PwdBox")
                $script:userpassword = $pwdobj
            }
            Else{
                $pwdbox = $false
            }
                
            Switch ($button) {
                1 {# Single button
                    # Object identification
                    $btn1 = $window.FindName("Button1")
                    $btn1.isDefault = $true

                    # Add events
                    $btn1.Add_Click({
                        $window.Close()
                        Stop-Process -id $PID
                    })
                }

                2 {# Two buttons
                    # Object identification
                    $btn1 = $window.FindName("Button1")
                    $btn2 = $window.FindName("Button2")

                    $btn1.isDefault = $true
                    $btn2.isCancel = $true

                    # Add events
                    $btn1.Add_Click({
                        $global:dialog_result = $true
                        $window.Close()
                    })

                    $btn2.Add_Click({
                        $global:dialog_result = $false
                        $window.Close()
                    })
                }
            }

            # Show the window to the user
            [void]$window.ShowDialog()
        }
        'process' {
            # Create a new runspace for the boxes to run in
            $global:syncHash = [hashtable]::Synchronized(@{})
            $new_runspace = [runspacefactory]::CreateRunspace()
            $new_runspace.ApartmentState = "STA"
            $new_runspace.ThreadOptions = "ReuseThread"
            $new_runspace.Open()
            $new_runspace.SessionStateProxy.SetVariable("syncHash",$syncHash)

            # Define the different boxes
            Switch ($type) {
                1 {
                    $command = [PowerShell]::Create().AddScript({
                        [xml]$msg = '
                        <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="<Company> iOS Archive Utility" Height="250" Width="270" WindowStartupLocation = "CenterScreen" ResizeMode="NoResize">
                            <Grid>
                                <StackPanel>
                                    <TextBlock Name="Text1" HorizontalAlignment="Center" Margin="0,75,0,5" Text="Processing. Please Wait."/>
                                    <ProgressBar x:Name="PBar" HorizontalAlignment="Center" Width="45" Height="20" IsIndeterminate="True"/>
                                    <TextBlock Name="Text2" HorizontalAlignment="Center" Margin="0,70,0,5" Text=" "/>
                                </StackPanel>
                            </Grid>
                        </Window>
                        '
                        # Window Constructor
                        $reader = New-Object System.Xml.XmlNodeReader $msg
                        $syncHash.Window = [Windows.Markup.XamlReader]::Load($reader)

                        # Object identification
                        $syncHash.StatusBox = $syncHash.Window.FindName("Text1")
                        $syncHash.InfoBox = $syncHash.Window.FindName("Text2")

                        # Handle the 'X' button
                        $syncHash.Window.Add_Closing({
                            if($syncHash.AutoClose -ne $true){
                                if(get-process -name imazing-cli){
                                    stop-process -name imazing-cli -force
                                }

                                $command.EndInvoke($result)
                                $command.Runspace.Dispose()
                                $command.Runspace.Close()
                                $command.Dispose()
                                Exit
                            }
                        })

                        # Show the window to the user
                        [void]$syncHash.Window.ShowDialog()
                        $command.EndInvoke($result)
                        $command.Runspace.Dispose()
                        $command.Runspace.Close()
                        $command.Dispose()
                    })
                }

                2 {
                    $command = [PowerShell]::Create().AddScript({
                        [xml]$msg = '
                        <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="<Company> iOS Archive Utility" Height="250" Width="270" WindowStartupLocation = "CenterScreen" ResizeMode="NoResize">
                            <Grid>
                                <StackPanel>
                                    <TextBlock Name="Text1" HorizontalAlignment="Center" Margin="0,75,0,5" Text=" "/>
                                    <ProgressBar x:Name="PBar" HorizontalAlignment="Center" Width="220" Height="20" IsIndeterminate="False" Value="0" Maximum="100"/>
                                    <TextBlock HorizontalAlignment="Center" Margin="0,70,0,5" Text="{Binding ElementName=PBar, Path=Value, StringFormat={}{0:0}%}"/>
                                </StackPanel>
                            </Grid>
                        </Window>
                        '
                        # Window Constructor
                        $reader = New-Object System.Xml.XmlNodeReader $msg
                        $syncHash.Window = [Windows.Markup.XamlReader]::Load($reader)

                        # Object identification
                        $syncHash.AutoClose = $false
                        $syncHash.Progress = $syncHash.Window.FindName("PBar")
                        $syncHash.StatusBox = $syncHash.Window.FindName("Text1")

                        # Handle the 'X' button
                        $syncHash.Window.Add_Closing({
                            if($syncHash.AutoClose -ne $true){
                                if(get-process -name imazing-cli){
                                    stop-process -name imazing-cli -force
                                }

                                if(test-path $onserver){
                                    remove-item -path $onserver -force
                                }

                                $command.EndInvoke($result)
                                $command.Runspace.Dispose()
                                $command.Runspace.Close()
                                $command.Dispose()
                                Exit
                            }
                        })

                        # Show the window to the user
                        [void]$syncHash.Window.ShowDialog()
                        $command.EndInvoke($result)
                        $command.Runspace.Dispose()
                        $command.Runspace.Close()
                        $command.Dispose()
                    })
                }
            }

            # Create tracking then open the runspace
            $command.Runspace = $new_runspace
            $result = $command.BeginInvoke()

        }
    }
}

Function Update-Message {
    Param(
        [string]$status,
        [string]$message
    )

    do{
        start-sleep -Milliseconds 10
    }until($syncHash.StatusBox.Dispatcher -ne $null)

    if($status){
        $syncHash.StatusBox.Dispatcher.Invoke(
            [action]{$syncHash.StatusBox.Text = $status},"Normal"
        )
    }

    if($message){
        $syncHash.InfoBox.Dispatcher.Invoke(
            [action]{$syncHash.InfoBox.Text = $message},"Normal"
        )
    }
}

Function Update-Progress ($step) {
    $syncHash.Progress.Dispatcher.Invoke(
        [action]{$syncHash.Progress.Value = $step},"Normal"
    )
}

Function Stop-Message {
    $syncHash.AutoClose = $true
    $syncHash.Window.Dispatcher.Invoke(
        [action]{$syncHash.Window.Close()},"Normal"
    )
}

Function Execute ($arguments) {
    $procinfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo
    $procinfo.FileName = $imazing
    $procinfo.RedirectStandardError = $true
    $procinfo.RedirectStandardOutput = $true
    $procinfo.CreateNoWindow = $true
    $procinfo.UseShellExecute = $false
    $procinfo.Arguments = $arguments

    $proc = New-Object -TypeName System.Diagnostics.Process
    $proc.StartInfo = $procinfo
    $proc.Start() | Out-Null
    If($arguments -notlike '--device-pair*'){
        $proc.WaitForExit()
    }
    Else{
        Do{
            Start-Sleep -Milliseconds 100
            $waited = $waited + 100
            If($waited -eq 15000){
                If(Get-Process -Name imazing-cli){
                    Stop-Process -Name imazing-cli
                }
            }
        }Until($proc.HasExited)
    }

    $script:stdout = $proc.StandardOutput.ReadToEnd()
    $script:stderr = $proc.StandardError.ReadToEnd()
}

Function Prepare-Launch {
    Update-Message -status "Loading"

    # Clear the imazing Cache
    if(test-path "$env:APPDATA\iMazing"){
        remove-item -path "$env:APPDATA\iMazing" -recurse -force
    }
    Update-Progress 25

    # Make sure the correct programs are running
    Try{Stop-Process -Name iTunesHelper -Force -ErrorAction Stop}
    Catch{Write-Output "iTunesHelper is not running"}

    Try{Stop-Process -Name iTunes -Force -ErrorAction Stop}
    Catch{Write-Output "iTunes is not running"}

    Try{Stop-Process -Name iPodService -Force -ErrorAction Stop}
    Catch{Write-Output "iPodService is not running"}

    Update-Progress 50

    Try{
        Get-Process -Name SyncServer -ErrorAction Stop | Out-Null
        Restart-Service -Name AppleSyncServer    
    }
    Catch{Start-Service -Name AppleSyncServer}

    Try{
        Get-Process -Name AppleMobileDeviceService -ErrorAction Stop | Out-Null
        Restart-Service -Name 'Apple Mobile Device Service'    
    }
    Catch{Start-Service -Name 'Apple Mobile Device Service'} 

    Update-Progress 75

    # Make sure there aren't any lingering backups
    $mobilesync = "$env:APPDATA\Apple Computer\MobileSync\Backup"

    If(Test-Path $mobilesync){
        $backups = Get-ChildItem -Path $mobilesync -Directory -Exclude 'iMazing.Versions'

        If($backups){
            ForEach($backup in $backups){
                    Remove-Item -Path $backup.FullName -Recurse -Force
            }
        }
    }
    Stop-Message
}

Function Check-Connectivity {
    # Check if an iOS device is connected to the computer.
    Update-Message -status "Processing. Please wait." -message "Looking for device"

    Execute "--device-list-all-connected --usb --timeout 15 --json"
    
    # Make the output powershell readable
    $convert = $stdout | ConvertFrom-Json

    # Check the status output to see if there's a UDID
    If($convert.Message.Value -match '\w+'){
        $script:udid = ($convert.Message.Value | Get-Member -MemberType NoteProperty).Name
        $script:no_device = $false
        Update-Message -message "Found device"
    }
    Else{
        $script:no_device = $true
        Update-Message -message "Could not find device"
    }
}

Function Pair-Device {
    # Pair the device with the computer
    Update-Message -status "Processing. Please wait." -message "Pairing device with computer"
    Execute "--device-pair --udid $($udid) --timeout 15 --json"

    If($stdout -match '(Please enter your passcode on the device)'){
        Stop-Message
        Get-Segment -mode prompt -type 4
        Return
    }

    $script:paired = $true
}

Function Check-Prereq {
    # Check to make sure the phone can run this program
    Update-Message -status "Processing. Please wait." -message "Checking prerequisites"
    Execute "--device-info --udid $($udid) --json"

    # Make the output powershell readable
    $convert = $stdout | ConvertFrom-Json
    $info = $convert.Message.Value."Advanced Info"

    # Check if the OS is 11+
    If($info."iOS Version:" -ne $null){
        If($info."iOS Version:" -lt 11){
            Stop-Message
            Get-Segment -mode prompt -type 5
        }
    }
    Else{
        Stop-Message
        Get-Segment -mode prompt -type 4
        Switch ($dialog_result) {
            'True' {
                Return
            }

            'False' {
                stop-process -Id $PID
            }
        }
    }

    # Get user's fullname with adsi
    $searcher = New-Object DirectoryServices.DirectorySearcher
    $searcher.Filter = "(sAMAccountName=$env:USERNAME)"
    $properties = $searcher.FindAll()
    $displayname = $properties.Properties.cn -Replace " ","_"

    If(!$displayname){
        $displayname = "UNKNOWN"
    }

    # Create parent directory
    If($info."Phone Number:" -match "[0-9]"){
        $phonenumber = $info."Phone Number:" -Replace '[+()-]|\s'
        $deviceid = "$displayname-$phonenumber"
        $parentdir = "$env:AppData\iMazing\Backups\$deviceid"
        If(-Not(Test-Path $parentdir)){
            Try{New-Item -Path "$env:AppData\iMazing\Backups" -Name $deviceid -ItemType Directory -Force -ErrorAction Stop}
            Catch{$_.Exception.Message}
        }
    }
    Else{
        $sn = $info."Serial Number:"
        $deviceid = "$displayname-$sn"
        $parentdir = "$env:AppData\iMazing\Backups\$deviceid"
        If(-Not(Test-Path $parentdir)){
            Try{New-Item -Path "$env:AppData\iMazing\Backups" -Name $deviceid -ItemType Directory -Force -ErrorAction Stop}
            Catch{$_.Exception.Message}
        }
    }

    $script:backupdir = "`"$($parentdir)`""
    $script:archivedir = $parentdir
    $output = @()
    $deviceinfo = [pscustomobject]@{
        'Name'=$info."Name:";
        'Phone Number'=$info."Phone Number:";
        'Model'=$info."Model:";
        'iOS Version'=$info."iOS Version:";
        'Wi-Fi MAC'=$info."Wi-Fi MAC Address:";
        'S/N'=$info."Serial Number:";
        'IMEI'=$info."IMEI:";
        'ECID'=$info."ECID:";
        'Device ID'=$info."Device ID:"
    }
    $output += $deviceinfo
    $output | Format-Table -Property * -AutoSize |
        Out-String -Width 4096 | Out-File -FilePath "$parentdir\Device Info.txt"

    $script:passprereq = $true
}

Function Check-Encryption {
    # Check the device for encryption
    Update-Message -status "Processing. Please wait." -message "Checking device health"
    Execute "--device-check-backup-encryption --udid $($udid) --json"

    $convert = $stdout | ConvertFrom-Json

    If($convert.Message.Value -eq "True"){
        $script:isencrypted = $true
    }
    Else{
        $script:isencrypted = $false
    }
}

Function Check-Pass ($password,$postmsg) {
    # Check the encryption password
    If($postmsg){
        Update-Message -status "Processing. Please wait." -message "Checking password"
    }
    Execute "--backup-device-verify-password --udid $($udid) --password $password"

    If($stdout -match '(No number found)'){
        $script:correctpass = $true
    }
    ElseIf($stdout -match '(Error number)'){
        $script:correctpass = $false
    }
}

Function Set-Pass ($to,$from) {
    Update-Message -status "Processing. Please wait." -message "Preparing device for backup"

    If($new){
        Execute "--backup-device-change-password --udid $($udid) --new-password $to"
    }
    Else{
        Execute "--backup-device-change-password --udid $($udid) --password $from --new-password $to"
    }
}

Function Backup-Device {
    Update-Message -status "Backing up device"

    $script:tempHash = [hashtable]::Synchronized(@{})
    $temp_runspace = [runspacefactory]::CreateRunspace()
    $temp_runspace.ApartmentState = "STA"
    $temp_runspace.ThreadOptions = "ReuseThread"
    $temp_runspace.Open()
    $temp_runspace.SessionStateProxy.SetVariable("tempHash",$tempHash)

    $parameters = @{
        param1 = $imazing
        param2 = $udid
        param3 = $backupdir
    }

    $scriptblock = {
        Param($param1,$param2,$param3)
        $procinfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo
        $procinfo.FileName = $param1
        $procinfo.RedirectStandardError = $true
        $procinfo.RedirectStandardOutput = $true
        $procinfo.CreateNoWindow = $true
        $procinfo.UseShellExecute = $false
        $procinfo.Arguments = "--backup-device --udid $param2 --backup-location-path $param3 --no-archiving --json"

        $proc = New-Object -TypeName System.Diagnostics.Process
        $proc.StartInfo = $procinfo
        $proc.Start() | Out-Null

        Do{
            $raw = $proc.StandardOutput.ReadLine()
        
            if($raw -match '(\d+%)'){
                $tempHash.Percent = $raw -replace '.*?(?=\d+%)|(?!$1).*'
                }
            elseif($raw -match '(Finishing)'){
                $tempHash.Percent = "100"
            }
            elseif($raw -match '(Stopping)'){
                $tempHash.Error = $true
            }
            elseif($raw -match '(iMazing could not back up)'){
                $tempHash.Error = $true
            }

        }Until($proc.HasExited)
    }

    $powershell = [PowerShell]::Create().AddScript($scriptblock)
    [void]$powershell.AddParameters($parameters)

    # Create tracking then open the runspace
    $powershell.Runspace = $temp_runspace
    $job = $powershell.BeginInvoke()

    While($tempHash.Percent -eq $null){Start-Sleep -Milliseconds 10}
    Do{
        Update-Progress $tempHash.Percent
    }Until(($tempHash.Percent -eq 100) -or ($tempHash.Error -eq $true))

    $powershell.EndInvoke($job)
    $powershell.Runspace.Dispose()
    $powershell.Runspace.Close()
    $powershell.Dispose()

    If($tempHash.Error -eq $true){
        Stop-Message
        Get-Segment -mode prompt -type 10
    }

    Remove-Item -Path "$archivedir\iMazing.Versions" -Recurse -Force
}


Function Create-Zip {
    If(Test-Path $archivedir){
        Update-Message -status "Creating zip file"

        $script:tempHash = [hashtable]::Synchronized(@{})
        $temp_runspace = [runspacefactory]::CreateRunspace()
        $temp_runspace.ApartmentState = "STA"
        $temp_runspace.ThreadOptions = "ReuseThread"
        $temp_runspace.Open()
        $temp_runspace.SessionStateProxy.SetVariable("tempHash",$tempHash)

        $parameters = @{
            param1 = $archivedir
        }

        $scriptblock = {
            Param($param1)
            # Load required assemblies
            Add-Type -AssemblyName System.IO.Compression
            Add-Type -AssemblyName System.IO.Compression.FileSystem

            # Define paths
            $here = (Get-Item -Path .\).FullName
            $source = $param1
            $dest = "$source.zip"

            # A blank directory needs to be made to create the zip archive
            $test = "$env:AppData\iMazing\Backups\Test"
            if(test-path $test){
                remove-item -path $test -force
            }
            else{
                new-item -path "$env:AppData\iMazing\Backups" -name "Test" -itemtype Directory
            }

            # Make sure there isn't already a zip archive present
            If(test-path $dest){
                remove-item -path $dest -force
            }

            # Set the compression level for the archive
            $compressionlevel = [System.IO.Compression.CompressionLevel]::Optimal

            # Create zip archive
            [System.IO.Compression.ZipFile]::CreateFromDirectory($test,$dest,$compressionlevel,$false)

            # Dispose of empyt shell folder
            remove-item -path $test -force

            # Get a listing of all the file paths necessary to create
            $children = get-childitem -path $source -recurse -force
            $count = $children.Count
            $i = 0

            $update = [System.IO.Compression.ZipArchiveMode]::Update
            [System.IO.Compression.ZipArchive]$archive = [System.IO.Compression.ZipFile]::Open($dest,$update)

            foreach($child in $children){
                if($child.PSIsContainer){
                    # make a name that honors file structure
                    $path = ($($child.FullName).Replace(($source + "\"),''))
                    if($path){
                        $name = $path.Replace("\","/")
                    }
                    else{
                        $name = $child.Name
                    }

                    # create the directory inside the archive
                    [void]$archive.CreateEntry("$name/")
                }
                else{
                    # figure out where in the structure the file should reside
                    $path = ($child.FullName).Replace(($source + "\"),'').Replace($child.Name,'')
                    if($path -match '\\'){
                        # at least one subdirectory exists
                        $name = $path.Replace("\","/") + $child.Name
                    }
                    else{
                        $name = $child.Name
                    }

                    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$child.FullName,$name,$compressionlevel)
                    $i++
                    $progress = ([int]($i/$count*100))
                }

                $tempHash.Percent = $progress

            }

            $archive.Dispose()
            $tempHash.Complete = $true
            $tempHash.Folder = $dest
        }

        $powershell = [PowerShell]::Create().AddScript($scriptblock)
        [void]$powershell.AddParameters($parameters)

        # Create tracking then open the runspace
        $powershell.Runspace = $temp_runspace
        $job = $powershell.BeginInvoke()

        While($tempHash.Percent -eq $null){Start-Sleep -Milliseconds 10}
        Do{
            Update-Progress $tempHash.Percent
        }Until($tempHash.Complete -eq $true)

        $script:zip = $tempHash.Folder
        $powershell.EndInvoke($job)
        $powershell.Runspace.Dispose()
        $powershell.Runspace.Close()
        $powershell.Dispose()
    }
}

Function Copy-File {
    Update-Message -status "Copying file to server"

    $name = $zip.Split("\") | Select -Last 1
    if(test-path "$share\$name"){
        $raw = $name -Replace '.zip'
        if(test-path -literalpath "$share\$raw [1].zip"){
            $current = get-childitem $share -filter "$($raw)*" -exclude $name | sort name | select -last 1
            [int]$number = ($current.Name -Split " " -Replace ".zip|[\[\]]")[1]
            $number++
            $name = "$raw [$number].zip"
        }
        else{
            $name = "$raw [1].zip"
        }
    }

    $script:tempHash = [hashtable]::Synchronized(@{})
    $temp_runspace = [runspacefactory]::CreateRunspace()
    $temp_runspace.ApartmentState = "STA"
    $temp_runspace.ThreadOptions = "ReuseThread"
    $temp_runspace.Open()
    $temp_runspace.SessionStateProxy.SetVariable("tempHash",$tempHash)

    $parameters = @{
        param1 = $zip
        param2 = $share
        param3 = $name
    }

    $scriptblock = {
        Param($param1,$param2,$param3)
        $onserver = "$param2\$param3"
        $from = [io.filestream]::new($param1, [io.filemode]::Open)
        $to = [io.filestream]::new($onserver, [io.filemode]::Create)
        try{
            [long]$length = $from.Length - 1
            [byte[]]$buffer = new-object byte[] 1024

            while($from.Position -lt $length){
                [int]$read = $from.Read($buffer, 0, 1024)
                $to.Write($buffer, 0, $read)
                $progress = [math]::Round($from.Position / $length * 100)
                $tempHash.Percent = $progress
            }
        }
        finally{
            $from.Dispose()
            $to.Dispose()
            $tempHash.Complete = $true
            $tempHash.Folder = $onserver
        }
    }

    $powershell = [PowerShell]::Create().AddScript($scriptblock)
    [void]$powershell.AddParameters($parameters)

    # Create tracking then open the runspace
    $powershell.Runspace = $temp_runspace
    $job = $powershell.BeginInvoke()

    While($tempHash.Percent -eq $null){Start-Sleep -Milliseconds 10}
    Do{
        Update-Progress $tempHash.Percent
    }Until($tempHash.Complete -eq $true)

    $script:copycomplete = $true
    $script:onserver = $tempHash.Folder
    $powershell.EndInvoke($job)
    $powershell.Runspace.Dispose()
    $powershell.Runspace.Close()
    $powershell.Dispose()
}

# Main Script
Get-Segment -mode process -type 2
Prepare-Launch
Get-Segment -mode prompt -type 1
Switch ($dialog_result) {
    'True' {
        Get-Segment -mode process -type 1
        Check-Connectivity
    }

    'False' {
        Stop-Process -id $PID
    }
}

If($no_device -eq $true){
    $i = 1
    Do{
        Stop-Message
        Get-Segment -mode prompt -type 2
        Switch ($dialog_result) {
            'True' {
                Get-Segment -mode process 1
                Check-Connectivity
            }
            
            'False' {
                Stop-Process -id $PID
            }
        }
        $i++
    }Until(($no_device -eq $false) -or ($i -gt 3))

    If($i -gt 3){
        Stop-Message
        Get-Segment -mode prompt -type 3
    }
}
Else{
    Pair-Device
    If($paired -ne $true){
        Do{
            Get-Segment -mode process -type 1
            Pair-Device
        }Until($paired -eq $true)
    }
}

Check-Prereq
If($passprereq -ne $true){
    Do{
        Get-Segment -mode process -type 1
        Check-Prereq
    }Until($passprereq -eq $true)
}

Check-Encryption
If($isencrypted -eq $true){
    Check-Pass $ours
    If($correctpass -ne $true){
        $i = 1
        Stop-Message                
        Do{
            Get-Segment -mode prompt -type 6
            Switch ($dialog_result) {
                'True' {
                    Get-Segment -mode process -type 1
                    Check-Pass $userpassword $true
                }

                'False' {
                    If($i -gt 1){
                        Get-Segment -mode prompt -type 8
                    }
                    Else{
                        Stop-Process -id $PID
                    }
                }
            }

            If($correctpass -ne $true){
                Stop-Message

                if($i -le 2){
                    Get-Segment -mode prompt -type 7
                    Switch ($dialog_result) {
                        'True' {
                            Continue
                        }

                        'False' {
                            If($i -gt 1){
                                Get-Segment -mode prompt -type 8
                            }
                            Else{
                                Stop-Process -id $PID
                            }
                        }
                    }
                }
            }

            $i++
        }Until(($correctpass -eq $true) -or ($i -gt 3))

        If($i -gt 3){
            Get-Segment -mode prompt -type 8
        }

        If($correctpass -eq $true){
            $changepassword = $true
        }
    }
}
Else{
    # Set the encryption password since there isn't one
    $script:new = $true
    Set-Pass $ours
}

If($changepassword -eq $true){
    # Set our password
    Set-Pass $ours $userpassword
}

# Begin the backup process
Stop-Message
Get-Segment -mode process -type 2
Backup-Device

# Create a zip archive
Stop-Message
Get-Segment -mode process -type 2
Create-Zip

# error check, look for successful zip archive
If(!$zip){
    Stop-Message
    Get-Segment -mode prompt -type 10
}

# Copy file
Stop-Message
Get-Segment -mode process -type 2
Copy-File

# error check, make sure copy was successful
If(!$copycomplete){
    Stop-Message
    Get-Segment -mode prompt -type 10
}

# quick cleanup
Stop-Message
Get-Segment -mode process -type 1
Update-Message -status "Performing some cleanup"
Try{
    Remove-Item -Path $archivedir -Recurse -Force -ErrorAction Stop
}
Catch{$_.Exception.Message}
Try{
    Remove-Item -Path "$archivedir.zip" -Force -ErrorAction Stop
}
Catch{$_.Exception.Message}
Update-Message -status "Done!"

# complete!
Stop-Message
Get-Segment -mode prompt -type 9
