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

# Check what extensions are already installed
# Script runs as system, so $env:LocalAppData cannot be used
$user_appdata = "C:\users\$env:username\AppData\Local"
$user_extensions = "$user_appdata\Google\Chrome\User Data\Default\Extensions"

If($user_extensions){
    $path_names = (Get-ChildItem -Path $user_extensions).Name
    ForEach($name in $path_names){$script:installed_extensions += $name}
}

# Function: Prompt if user wants to close Chrome
Function ChoicePrompt {
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

    If($result -eq [System.Windows.Forms.DialogResult]::Yes){Get-Process | Where{$_.name -match "Chrome"} | Stop-Process}
    If($result -eq [System.Windows.Forms.DialogResult]::No){ Exit }
    If($result -eq [System.Windows.Forms.DialogResult]::Cancel){ Exit }
}

# Function: Create the extensions selection list
Function ExtensionsPrompt {
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
    $label.Text = "Select which Chrome extension(s) you would like to install:"
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
    ForEach($extension in $whitelist_file){
        If($extension.Key -notin $script:installed_extensions){$CheckedListBox.Items.Add($extension.Extension) | Out-Null}
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

# Run the user prompts
ChoicePrompt
ExtensionsPrompt

# Check for requisite registry policy paths
If(-Not(Test-Path $Google_Root)){New-Item -Path 'HKLM:\SOFTWARE\Policies' -Name "Google"}
If(-Not(Test-Path $Chrome_Root)){New-Item -Path $Google_Root -Name "Chrome"}
If(-Not(Test-Path $Whitelist_Reg)){New-Item -Path $Chrome_Root -Name "ExtensionInstallWhitelist"}
If(-Not(Test-Path $Forcelist_Reg)){New-Item -Path $Chrome_Root -Name "ExtensionInstallForcelist"}
If(-Not(Test-Path $Blacklist_Reg)){New-Item -Path $Chrome_Root -Name "ExtensionInstallBlacklist"}

# Create the implicit deny in the blacklist
# What's the point of a whitelist if you could install anything you wanted anyways?
New-ItemProperty -Path $Blacklist_Reg -Name "1" -Value "*" -Force -ErrorAction SilentlyContinue

# Translate the selected extension common names to their chrome store IDs
$script:Translated = @()
ForEach($Line in $whitelist_file){
    If($Line.Extension -in $selected_extensions){$Translated += $Line.Key}
}

# Run the install functions
KeyWrite -RegPath $Whitelist_Reg -Force $false
KeyWrite -RegPath $Forcelist_Reg -Force $true
