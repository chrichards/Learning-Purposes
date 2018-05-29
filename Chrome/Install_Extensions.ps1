###################### Pre-Setup ##########################
# Key Paths
$Google_Root = "HKLM:\SOFTWARE\Policies\Google"
$Chrome_Root = "$Google_Root\Chrome"
$Whitelist_Reg = "$Chrome_Root\ExtensionInstallWhitelist"
$Forcelist_Reg = "$Chrome_Root\ExtensionInstallForcelist"
$Blacklist_Reg = "$Chrome_Root\ExtensionInstallBlacklist"
$Google_Install = ";https://clients2.google.com/service/update2/crx"

# Whitelisted extensions
$script:whitelist_file = Import-CSV .\whitelist.csv

# Installed extensions
$script:installed_extensions = @()

# Selected extensions
$script:selected_extensions = @()

# Install/Uninstall choice switch
$script:install = $null

# Check what extensions are already installed
# Script runs as system, so $env:LocalAppData cannot be used
$script:username = (Get-Process -IncludeUserName | Where{$_.name -match "explorer"}).UserName
$username_clean = $username.Replace("[domain]\","")
$user_appdata = "C:\users\$username_clean\AppData\Local"
$script:user_extensions = "$user_appdata\Google\Chrome\User Data\Default\Extensions"

If(Test-Path $user_extensions){
    $path_names = (Get-ChildItem -Path $user_extensions).Name
    ForEach($name in $path_names){$script:installed_extensions += $name}
}

# Check for requisite registry policy paths
If(-Not(Test-Path $Google_Root)){New-Item -Path 'HKLM:\SOFTWARE\Policies' -Name "Google"}
If(-Not(Test-Path $Chrome_Root)){New-Item -Path $Google_Root -Name "Chrome"}
If(-Not(Test-Path $Whitelist_Reg)){New-Item -Path $Chrome_Root -Name "ExtensionInstallWhitelist"}
If(-Not(Test-Path $Forcelist_Reg)){New-Item -Path $Chrome_Root -Name "ExtensionInstallForcelist"}
If(-Not(Test-Path $Blacklist_Reg)){New-Item -Path $Chrome_Root -Name "ExtensionInstallBlacklist"}

# Create the implicit deny in the blacklist
# What's the point of a whitelist if you could install anything you wanted anyways?
New-ItemProperty -Path $Blacklist_Reg -Name "1" -Value "*" -Force -ErrorAction SilentlyContinue


###################### Functions ##########################
# Function: Ask user if they want to install or uninstall extensions
Function InstallUninstallPrompt {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form 
    $form.Text = "Install or Uninstall?"
    $form.Size = New-Object System.Drawing.Size(300,170) 
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'Fixed3D'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(15,20) 
    $label.Size = New-Object System.Drawing.Size(250,40) 
    $label.Text = "Would you like to install or uninstall an extension?"
    $form.Controls.Add($label)

    $YesButton = New-Object System.Windows.Forms.Button
    $YesButton.Location = New-Object System.Drawing.Point(50,80)
    $YesButton.Size = New-Object System.Drawing.Size(75,23)
    $YesButton.Text = "Install"
    $YesButton.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $form.AcceptButton = $YesButton
    $form.Controls.Add($YesButton)

    $NoButton = New-Object System.Windows.Forms.Button
    $NoButton.Location = New-Object System.Drawing.Point(150,80)
    $NoButton.Size = New-Object System.Drawing.Size(75,23)
    $NoButton.Text = "Uninstall"
    $NoButton.DialogResult = [System.Windows.Forms.DialogResult]::No
    $form.CancelButton = $NoButton
    $form.Controls.Add($NoButton)
    $form.Topmost = $True

    $form.Add_Shown({$form.Activate()})
    $result = $form.ShowDialog()

    If($result -eq [System.Windows.Forms.DialogResult]::Yes){$script:install = $true}
    If($result -eq [System.Windows.Forms.DialogResult]::No){$script:install = $false}
    If($result -eq [System.Windows.Forms.DialogResult]::Cancel){ Exit }
}

# Function: Prompt if user wants to close Chrome
Function CloseChromePrompt {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form 
    $form.Text = "Close Chrome?"
    $form.Size = New-Object System.Drawing.Size(300,170) 
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'Fixed3D'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(15,20) 
    $label.Size = New-Object System.Drawing.Size(250,40) 
    $label.Text = "Before installing extensions, Chrome will need to be closed. Would you like to continue?"
    $form.Controls.Add($label)

    $YesButton = New-Object System.Windows.Forms.Button
    $YesButton.Location = New-Object System.Drawing.Point(50,80)
    $YesButton.Size = New-Object System.Drawing.Size(75,23)
    $YesButton.Text = "Yes"
    $YesButton.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $form.AcceptButton = $YesButton
    $form.Controls.Add($YesButton)

    $NoButton = New-Object System.Windows.Forms.Button
    $NoButton.Location = New-Object System.Drawing.Point(150,80)
    $NoButton.Size = New-Object System.Drawing.Size(75,23)
    $NoButton.Text = "No"
    $NoButton.DialogResult = [System.Windows.Forms.DialogResult]::No
    $form.CancelButton = $NoButton
    $form.Controls.Add($NoButton)
    $form.Topmost = $True

    $form.Add_Shown({$form.Activate()})
    $result = $form.ShowDialog()

    If($result -eq [System.Windows.Forms.DialogResult]::Yes){Get-Process | Where{$_.name -match "Chrome"} | Stop-Process -Force}
    If($result -eq [System.Windows.Forms.DialogResult]::No){ Exit }
    If($result -eq [System.Windows.Forms.DialogResult]::Cancel){ Exit }
}

# Function: Create the extensions selection list
Function ExtensionsPrompt {
    Param([boolean]$Uninstall)

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form 
    $form.Text = "Extension Selection"
    $form.Size = New-Object System.Drawing.Size(440,485) 
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'Fixed3D'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(15,20) 
    $label.Size = New-Object System.Drawing.Size(350,20)
    If($Uninstall -eq $false){$label.Text = "Select which Chrome extension(s) you would like to install:"}
    If($Uninstall -eq $true){$label.Text = "Select which Chrome extension(s) you would like to uninstall:"}
    $form.Controls.Add($label)

    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(115,405)
    $OKButton.Size = New-Object System.Drawing.Size(75,23)
    $OKButton.Text = "OK"
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $OKButton
    $form.Controls.Add($OKButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Point(230,405)
    $CancelButton.Size = New-Object System.Drawing.Size(75,23)
    $CancelButton.Text = "Cancel"
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $CancelButton
    $form.Controls.Add($CancelButton)

    $CheckedListBox = New-Object System.Windows.Forms.CheckedListBox
    $CheckedListBox.Location = New-Object System.Drawing.Point(15,40)
    $CheckedListBox.Size = New-Object System.Drawing.Size(390,350)
    If($Uninstall -eq $false){
        ForEach($extension in $whitelist_file){
            If($extension.Key -notin $script:installed_extensions){$CheckedListBox.Items.Add($extension.Extension) | Out-Null}
        }
    }
    If($Uninstall -eq $true){
        ForEach($extension in $script:Translated){$CheckedListBox.Items.Add($extension) | Out-Null}
    }
    $CheckedListBox.CheckOnClick = $true
    $CheckedListBox.SelectedIndex = 0
    $form.Controls.Add($CheckedListBox)

    $form.Topmost = $True

    $form.Add_Shown({$form.Activate()})
    $result = $form.ShowDialog()

    If($result -eq [System.Windows.Forms.DialogResult]::OK){ ForEach($Selection in $CheckedListBox.CheckedItems){$script:selected_extensions += $Selection} }
    If($result -eq [System.Windows.Forms.DialogResult]::Cancel){ Exit }
}

# Function: Give the user a status (Nothing to install/Installation complete)
Function StatusPrompt {
    Param([int]$ReadyState)

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form 
    $form.Text = "Status"
    $form.Size = New-Object System.Drawing.Size(250,170) 
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'Fixed3D'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label 
    $label.Size = New-Object System.Drawing.Size(250,40) 
    If($ReadyState -eq 0){
        $label.Location = New-Object System.Drawing.Point(35,20)
        $label.Text = "Extension(s) installed successfully!"
    }
    If($ReadyState -eq 1){
        $label.Location = New-Object System.Drawing.Point(25,20)
        $label.Text = "Extension(s) uninstalled successfully!"
    }  
    If($ReadyState -eq 2){
        $label.Location = New-Object System.Drawing.Point(45,20)
        $label.Text = "No extension(s) to uninstall!"
    }
    $form.Controls.Add($label)

    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(75,80)
    $OKButton.Size = New-Object System.Drawing.Size(75,23)
    $OKButton.Text = "OK"
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $OKButton
    $form.Controls.Add($OKButton)

    $form.Topmost = $True

    $form.Add_Shown({$form.Activate()})
    $result = $form.ShowDialog()

    If($result -eq [System.Windows.Forms.DialogResult]::Yes){ Exit }
    If($result -eq [System.Windows.Forms.DialogResult]::Cancel){ Exit }
}

# Function: Make user task to run chrome
Function ScheduleChrome {
    $ShedService = New-Object -COM 'Schedule.Service'
    $ShedService.Connect()

    $Task = $ShedService.NewTask(0)
    $Task.RegistrationInfo.Description = 'Create user FR folders'
    $Task.Settings.Enabled = $true
    $Task.Settings.Hidden = $true
    $Task.Settings.AllowDemandStart = $true

    $trigger = $task.triggers.Create(1)
    $addtime = (Get-Date).AddSeconds(5).ToString("yyyy-MM-ddTHH:mm:ss")
    $trigger.StartBoundary = $addtime
    $trigger.Enabled = $true

    $action = $Task.Actions.Create(0)
    $action.Path = 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
    $action.Arguments = '--silent-launch'

    $user = $username
    $taskFolder = $ShedService.GetFolder("\")
    $taskFolder.RegisterTaskDefinition('TEMP', $Task , 6, $user, $null, 0)
}

# Function: Wait for all extensions to be installed
Function InstallWait {
    Param([boolean]$Install)

    If($Install -eq $true){$installed_number = 0;$goal = $Translated.Count}
    If($Install -eq $false){$installed_number = $Translated.Count;$goal = 0}
    Do{
        $path_names = (Get-ChildItem -Path $user_extensions).Name
        If($installed_number -ne $goal){
            ForEach($extension in $path_names){
                If($extension -in $Translated){
                    If($Install -eq $true){$installed_number++}
                    If($install -eq $false){$installed_number--}
                    $Translated = ($Translated -replace $extension,'')
                }
                Else{Start-Sleep -Milliseconds 100}
            }
        }
        Else{
            Do{
                ForEach($extension in $path_names){
                    If($extension -eq 'Temp'){Start-Sleep -Milliseconds 100}
                    Else{$complete = $true}
                }
            }Until($complete -eq $true)
            Get-Process | Where{$_.name -match "chrome"} | Stop-Process -Force
            Remove-Item -Path "C:\Windows\System32\Tasks\TEMP" -Force
            $done = $true
        }
    }Until($done -eq $true)
}

# Function: Look through the registry path for missing keys or matching values and create keys
# See what whitelist policies are implemented
Function KeyWrite {
    Param([string]$RegPath,[boolean]$Force)

    Try{$List_Keys = Get-Item -Path $RegPath}
    Catch{$_.Exception.Message}

    # First, see if there are any numbers missing
    # If there is a break in the sequence, Chrome will not recognize anything beyond the break
    # Also check to see if any of the values correspond with user selected ones from $Translated
    If(($List_Keys).Property.Count -ge 1){
        $NumberTable = @()
        $MissingNumbers = @()

        ForEach($Value in $List_Keys.Property){
            $Compare = Get-ItemPropertyValue -Path $RegPath -Name $Value
            If($Compare -in $Translated){$Translated = ($Translated -replace $Compare,'')}
            $NumberTable += [convert]::ToInt32($Value,10)
        }
        $NumberTable = $NumberTable | Sort
        $LastValue = ($NumberTable | Select -last 1)
        $Temp = (1..$LastValue)
    
        ForEach($Number in $Temp){
            If($Number -notin $NumberTable){$MissingNumbers += $Number}
        }
    }
    Else{$Start = 1}

    # If there are missing numbers, fill in the gaps. Otherwise, start at 1 or wherever the last value left off
    If($MissingNumbers -ne $null){
        $i = 0; $a = 0
        Do{
            If($Translated[$a] -ne ''){
                If($Force -eq $true){$Translated[$a] = $Translated[$a]+$Google_Install}
                New-ItemProperty -Path $RegPath -Name $MissingNumbers[$i] -Value $Translated[$a]; $i++
            }
            $a++
        }Until($i -eq $MissingNumbers.Count)
        Do{
            If($Force -eq $true){$Translated[$a] = $Translated[$a]+$Google_Install}
            $LastValue = $LastValue + 1
            New-ItemProperty -Path $RegPath -Name $LastValue -Value $Translated[$a]
            $a++
        }Until($a -eq $Translated.Count)        
    }
    Else{
        If($Start){
            ForEach($Item in $Translated){
                If($Force -eq $true){$Item = $Item+$Google_Install}
                New-ItemProperty -Path $RegPath -Name $Start -Value $Item; $Start++
            }
        }
        Else{
            $LastValue = $LastValue + 1
            ForEach($Item in $Translated){
                If($Force -eq $true){$Item = $Item+$Google_Install}
                New-ItemProperty -Path $RegPath -Name $LastValue -Value $Item; $LastValue++
            }
        }
    }
}

# Function: Remove keys to uninstall extensions
Function KeyRemove {
    Param([string]$RegPath,[boolean]$Force)

    Try{$List_Keys = Get-Item -Path $RegPath}
    Catch{$_.Exception.Message}

    # Look for keys that match the user's selection, tear them out, and rebuild the index
    If(($List_Keys).Property.Count -ge 1){
        $AddExtensionsBack = @()

        ForEach($Value in $List_Keys.Property){
            $Compare = Get-ItemPropertyValue -Path $RegPath -Name $Value
            If($Force -eq $true){$Compare = $Compare -replace $Google_Install,''}
            If($Compare -in $Translated){Remove-ItemProperty -Path $RegPath -Name $Value}
            Else{$AddExtensionsBack += ($Compare+$Google_Install)}
        }

        # Re-get all the values in the reg key
        Try{$List_Keys = Get-Item -Path $RegPath}
        Catch{$_.Exception.Message}

        ForEach($Value in $List_Keys.Property){Remove-ItemProperty -Path $RegPath -Name $Value}
    
        For($i=0;$i -lt $AddExtensionsBack.Count;$i++){New-ItemProperty -Path $RegPath -Name ($i+1) -Value $AddExtensionsBack[$i]}
    }
}

###################### Run Block ##########################
# Run the user prompts
InstallUninstallPrompt
If($install -eq $true){
    If((get-process | where{$_.name -match "chrome"})){ CloseChromePrompt }
    ExtensionsPrompt -Uninstall $false

    # Translate the selected extension common names to their chrome store IDs
    $script:Translated = @()
    ForEach($Line in $whitelist_file){
        If($Line.Extension -in $selected_extensions){$Translated += $Line.Key}
    }

    # Run the install functions
    KeyWrite -RegPath $Whitelist_Reg -Force $false
    KeyWrite -RegPath $Forcelist_Reg -Force $true
    ScheduleChrome
    InstallWait -Install $true
    StatusPrompt -ReadyState 0
}
If($install -eq $false){

    # Translate the installed extension chrome store IDs to their common names
    $script:Translated = @()
    ForEach($Line in $whitelist_file){
        If($Line.Key -in $installed_extensions){$Translated += $Line.Extension}
    }

    If($Translated.Count -lt 1){StatusPrompt -ReadyState 2}
    Else{
        If((get-process | where{$_.name -match "chrome"})){ CloseChromePrompt }
        ExtensionsPrompt -Uninstall $true

        # Translate the selected extension common names to their chrome store IDs
        $script:Translated = @()
        ForEach($Line in $whitelist_file){
            If($Line.Extension -in $selected_extensions){$Translated += $Line.Key}
        }

        # Run the removal functions
        KeyRemove -RegPath $Whitelist_Reg -Force $false
        KeyRemove -RegPath $Forcelist_Reg -Force $true
        ScheduleChrome
        InstallWait -Install $false
        StatusPrompt -ReadyState 1
    }
}
