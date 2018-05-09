# Check if Local Intranet is in Protected Mode
$IsLIinProtectedMode = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\1").2500
$IsTrustedinProtectedMode = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\2").2500
If($IsLIinProtectedMode -ne "0"){ New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\1" -Name "2500" -PropertyType DWORD -Value "0" -Force | Out-Null }
If($IsTrustedinProtectedMode -ne "0"){ New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\2" -Name "2500" -PropertyType DWORD -Value "0" -Force | Out-Null }

# Define global variables
$global:stored_username = $null
$global:stored_password = $null
$global:users_issue = $null
$global:users_software = $null
$global:software_need = $null
$global:recurrence_choice = $null
$global:user_description = $null
$global:User_Properties = $null
$global:selected_user = $null
$global:selected_user_accountname = $null
$global:users_computername = $null

# Define current location
$IP = (Get-WMIObject Win32_NetworkAdapterConfiguration | ?{$_.ipenabled}).IPAddress

If($IP -like “10.10.*”){ $local = “10031” }
If($IP -like “10.32.*”){ $local = “10030” }
If(($IP -like “172.16.*”) -or ($IP -like “10.172.*”)){ $local = “10032” }
If($IP -like “10.43.*”){ $local = “10090” }
If($IP -like “10.54.*”){ $local = “10100” }

# Define browser object
$website = "https://jira.somecompany.com/secure/Dashboard.jspa"
$browser = New-Object -ComObject "InternetExplorer.Application"

# Function: Prompt for user's credentials
Function CredentialPrompt {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form 
    $form.Text = "Ticket Maker"
    $form.Size = New-Object System.Drawing.Size(300,200) 
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'Fixed3D'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(75,120)
    $OKButton.Size = New-Object System.Drawing.Size(75,23)
    $OKButton.Text = "OK"
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $OKButton
    $form.Controls.Add($OKButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Point(150,120)
    $CancelButton.Size = New-Object System.Drawing.Size(75,23)
    $CancelButton.Text = "Cancel"
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $CancelButton
    $form.Controls.Add($CancelButton)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,20) 
    $label.Size = New-Object System.Drawing.Size(280,20) 
    $label.Text = "Username:"
    $form.Controls.Add($label) 

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,70) 
    $label.Size = New-Object System.Drawing.Size(280,20) 
    $label.Text = "Password:"
    $form.Controls.Add($label) 

    $textBox = New-Object System.Windows.Forms.TextBox 
    $textBox.Location = New-Object System.Drawing.Point(10,40) 
    $textBox.Size = New-Object System.Drawing.Size(260,20) 
    $form.Controls.Add($textBox) 

    $maskedtextBox = New-Object System.Windows.Forms.MaskedTextBox
    $maskedtextBox.PasswordChar = '*' 
    $maskedtextBox.Location = New-Object System.Drawing.Point(10,90) 
    $maskedtextBox.Size = New-Object System.Drawing.Size(260,20) 
    $form.Controls.Add($maskedtextBox)

    $form.Topmost = $True

    $form.Add_Shown({$form.Activate();$textBox.Focus()})
    $result = $form.ShowDialog()

    If($result -eq [System.Windows.Forms.DialogResult]::OK){ 
        $global:stored_username = $textBox.Text
        $global:stored_password = $maskedtextBox.Text
    }
    If($result -eq [System.Windows.Forms.DialogResult]::Cancel){ Exit }
}

# Function: Get information about the user creating the ticket
Function Get-ADInformation{
    Param ([string]$SAMaccountname)
$Searcher = New-Object DirectoryServices.DirectorySearcher
$Searcher.Filter = "(SAMAccountName=$SAMaccountName)"
$Raw_Properties = $Searcher.FindAll()
$global:User_Properties = $Raw_Properties.Properties
}

# Function: Generate a list of reportable users
Function UserSelectPrompt {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form 
    $form.Text = "User Select"
    $form.Size = New-Object System.Drawing.Size(300,170) 
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'Fixed3D'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(15,20) 
    $label.Size = New-Object System.Drawing.Size(280,20) 
    $label.Text = "Who is having the issue?"
    $form.Controls.Add($label)

    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(50,80)
    $OKButton.Size = New-Object System.Drawing.Size(75,23)
    $OKButton.Text = "OK"
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $OKButton
    $form.Controls.Add($OKButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Point(150,80)
    $CancelButton.Size = New-Object System.Drawing.Size(75,23)
    $CancelButton.Text = "Cancel"
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $CancelButton
    $form.Controls.Add($CancelButton)

    $DropDown = New-Object System.Windows.Forms.ComboBox
    $DropDown.Location = New-Object System.Drawing.Point(15,40)
    $DropDown.Size = New-Object System.Drawing.Size(250,20)
    $DropDown.Items.Add("Me") | Out-Null
    If($arrayDirectReports){
        $DropDown.Items.Add("Multiple People") | Out-Null
        ForEach($objPerson in $arrayDirectReports){
            $DropDown.Items.Add($objPerson) | Out-Null
        }
    }
    $DropDown.SelectedIndex = 0
    $DropDown.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $form.Controls.Add($DropDown)

    $form.Topmost = $True

    $form.Add_Shown({$form.Activate()})
    $result = $form.ShowDialog()

    If($result -eq [System.Windows.Forms.DialogResult]::OK){ $global:selected_user = $DropDown.Text }
    If($result -eq [System.Windows.Forms.DialogResult]::Cancel){ Exit }
}

# FUnction: Ask what type of issue the user is having
Function IssueTypePrompt {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form 
    $form.Text = "Issue Type"
    $form.Size = New-Object System.Drawing.Size(300,170) 
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'Fixed3D'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(15,20) 
    $label.Size = New-Object System.Drawing.Size(280,20) 
    $label.Text = "What kind of problem are you having?"
    $form.Controls.Add($label)

    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(50,80)
    $OKButton.Size = New-Object System.Drawing.Size(75,23)
    $OKButton.Text = "OK"
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $OKButton
    $form.Controls.Add($OKButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Point(150,80)
    $CancelButton.Size = New-Object System.Drawing.Size(75,23)
    $CancelButton.Text = "Cancel"
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $CancelButton
    $form.Controls.Add($CancelButton)

    $DropDown = New-Object System.Windows.Forms.ComboBox
    $DropDown.Location = New-Object System.Drawing.Point(15,40)
    $DropDown.Size = New-Object System.Drawing.Size(250,20)
    $DropDown.Items.Add("Hardware") | Out-Null
    $DropDown.Items.Add("Software") | Out-Null
    $DropDown.Items.Add("Need Software Installed") | Out-Null
    $DropDown.Items.Add("General/Unknown") | Out-Null
    $DropDown.SelectedIndex = 0
    $DropDown.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $form.Controls.Add($DropDown)

    $form.Topmost = $True

    $form.Add_Shown({$form.Activate()})
    $result = $form.ShowDialog()

    If($result -eq [System.Windows.Forms.DialogResult]::OK){ $global:users_issue = $DropDown.Text }
    If($result -eq [System.Windows.Forms.DialogResult]::Cancel){ Exit }
}

# Function: Ask if this is a reoccuring issue
Function CommonIssuePrompt {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form 
    $form.Text = "Recurrence"
    $form.Size = New-Object System.Drawing.Size(300,170) 
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'Fixed3D'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

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

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(70,20) 
    $label.Size = New-Object System.Drawing.Size(280,20) 
    $label.Text = "Is this a reoccurring issue?"
    $form.Controls.Add($label) 

    $form.Topmost = $True

    $form.Add_Shown({$form.Activate()})
    $result = $form.ShowDialog()

    If($result -eq [System.Windows.Forms.DialogResult]::Yes){ $global:recurrence_choice = "Yes" }
    If($result -eq [System.Windows.Forms.DialogResult]::No){ $global:recurrence_choice = "No" }
    If($result -eq [System.Windows.Forms.DialogResult]::Cancel){ Exit }
}

# Function: Input box for the user's software request
Function SoftwareInstallPrompt {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form 
    $form.Text = "Name of Software"
    $form.Size = New-Object System.Drawing.Size(300,170) 
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'Fixed3D'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(60,85)
    $OKButton.Size = New-Object System.Drawing.Size(75,23)
    $OKButton.Text = "OK"
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $OKButton
    $form.Controls.Add($OKButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Point(135,85)
    $CancelButton.Size = New-Object System.Drawing.Size(75,23)
    $CancelButton.Text = "Cancel"
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $CancelButton
    $form.Controls.Add($CancelButton)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,20) 
    $label.Size = New-Object System.Drawing.Size(280,20) 
    $label.Text = "What's the name of the software you need?"
    $form.Controls.Add($label) 

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Multiline = $true 
    $textBox.Location = New-Object System.Drawing.Point(10,40) 
    $textBox.Size = New-Object System.Drawing.Size(260,20) 
    $form.Controls.Add($textBox) 

    $form.Topmost = $True

    $form.Add_Shown({$form.Activate();$textBox.Focus()})
    $result = $form.ShowDialog()

    If($result -eq [System.Windows.Forms.DialogResult]::OK){ $global:users_software = $textBox.Text }
    If($result -eq [System.Windows.Forms.DialogResult]::Cancel){ Exit }
}

# Function: Input box that corresponds to software request; business need
Function BusinessNeedPrompt {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form 
    $form.Text = "Business Need"
    $form.Size = New-Object System.Drawing.Size(300,300) 
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'Fixed3D'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(75,225)
    $OKButton.Size = New-Object System.Drawing.Size(75,23)
    $OKButton.Text = "OK"
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $OKButton
    $form.Controls.Add($OKButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Point(150,225)
    $CancelButton.Size = New-Object System.Drawing.Size(75,23)
    $CancelButton.Text = "Cancel"
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $CancelButton
    $form.Controls.Add($CancelButton)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,20) 
    $label.Size = New-Object System.Drawing.Size(280,20) 
    $label.Text = "Please type a brief reason for needing this software:"
    $form.Controls.Add($label) 

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Multiline = $true 
    $textBox.Location = New-Object System.Drawing.Point(10,40) 
    $textBox.Size = New-Object System.Drawing.Size(260,175) 
    $form.Controls.Add($textBox) 

    $form.Topmost = $True

    $form.Add_Shown({$form.Activate();$textBox.Focus()})
    $result = $form.ShowDialog()

    If($result -eq [System.Windows.Forms.DialogResult]::OK){ $global:software_need = $textBox.Text }
    If($result -eq [System.Windows.Forms.DialogResult]::Cancel){ Exit }
}

# Function: Input box for the user's general description of the problem
Function DescriptionPrompt {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form 
    $form.Text = "Summary"
    $form.Size = New-Object System.Drawing.Size(300,300) 
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'Fixed3D'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(75,225)
    $OKButton.Size = New-Object System.Drawing.Size(75,23)
    $OKButton.Text = "OK"
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $OKButton
    $form.Controls.Add($OKButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Point(150,225)
    $CancelButton.Size = New-Object System.Drawing.Size(75,23)
    $CancelButton.Text = "Cancel"
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $CancelButton
    $form.Controls.Add($CancelButton)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,20) 
    $label.Size = New-Object System.Drawing.Size(280,20) 
    $label.Text = "Please type a brief description of your problem:"
    $form.Controls.Add($label) 

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Multiline = $true 
    $textBox.Location = New-Object System.Drawing.Point(10,40) 
    $textBox.Size = New-Object System.Drawing.Size(260,175) 
    $form.Controls.Add($textBox) 

    $form.Topmost = $True

    $form.Add_Shown({$form.Activate();$textBox.Focus()})
    $result = $form.ShowDialog()

    If($result -eq [System.Windows.Forms.DialogResult]::OK){ $global:user_description = $textBox.Text }
    If($result -eq [System.Windows.Forms.DialogResult]::Cancel){ Exit }
}

# Function: gets a computername for a specific username
Function GetSCCMComputer {
Param($SamAccountName)
    $SiteName="[site code]"
    $SCCMServer="[FQDN of MP]"
    $SCCMNameSpace="root\sms\site_$SiteName"
    $global:users_computername = (Get-WmiObject -namespace $SCCMNameSpace -computer $SCCMServer -query "select Name from sms_r_system where LastLogonUserName='$SamAccountName'").Name
}

# Function: Wait for the browser to be in a ready state before taking action
Function Wait-Loop {
    Param ([string]$LookForTag,[string]$LookForID,[string]$LookForText)
    Do{
        Start-Sleep -Milliseconds 500
        If($browser.ReadyState -eq 4){
            $TagCheckList = (($browser.Document).getElementsbyTagName($LookForTag))
            ForEach($tag in $TagCheckList){
                If($tag.id -ne $null){
                    If($tag.id -eq $LookForID){ $target = $tag }
                }
            }
            $CheckForElement = $target.innerText
            $ElementMatch = $CheckForElement -match $LookingFor
        }
    } Until($ElementMatch)
}

# Prompt for user input/define multiple ticket variables
CredentialPrompt
$attempts = 1
Get-ADInformation -SAMaccountname $global:stored_username
    If($global:User_Properties.directreports){
        $directReports = $global:User_Properties.directreports | %{($_.Split(",")[0] -replace "CN=","")} | Sort
        $arrayDirectReports = @()
        $tableDirectReports = @{}
        ForEach($person in $directReports){ 
            Get-ADInformation -SAMaccountname $person
            $arrayDirectReports += $global:User_Properties.displayname
            $tableDirectReports.Add([string]$global:User_Properties.displayname, [string]$global:User_Properties.samaccountname)
        }
    }
UserSelectPrompt
If($tableDirectReports){ 
    $selected_user_samaccountname = $tableDirectReports.Get_Item($global:selected_user)
    GetSCCMComputer -SamAccountName $selected_user_samaccountname
}
If($global:selected_user -eq "Me"){ GetSCCMComputer -SamAccountName $global:stored_username }
If($global:selected_user -eq "Multiple People"){ $global:users_computername = "Unknown" }
IssueTypePrompt
If(($global:users_issue -eq "Hardware") -or ($global:users_issue -eq "Software")){ CommonIssuePrompt }
If($global:users_issue -eq "Need Software Installed"){ SoftwareInstallPrompt }
If($global:users_software -ne $null){ BusinessNeedPrompt }
Else{ DescriptionPrompt }

If($global:users_computername){
    If($global:users_computername.count -gt 1){ $global:users_computername = $global:users_computername[0] }
    Try{
        $query_uptime = Get-WMIObject -ClassName Win32_OperatingSystem -ComputerName $global:users_computername | Select @{Label='LastBootUpTime';Expression={$_.ConverttoDateTime($_.LastBootUpTime)}}
        $uptime = $query_uptime.LastBootUpTime
    }
    Catch{ $uptime = "Unknown" }
}
Else{
    $global:users_computername = "Unknown"
    $uptime = "Unknown"
}

# Define department user belongs to
If($global:User_Properties.department -eq "Carrier Relations"){ $user_department = "11302" }
If($global:User_Properties.department -eq "Clerical"){ $user_department = "" }
If(($global:User_Properties.department -eq "Cust Comm and Retention") -or ($global:User_Properties.department -eq "Customer Service")){ $user_department = "11303" }
If($global:User_Properties.department -eq "Enrollment"){ $user_department = "11304" }
If(($global:User_Properties.department -eq "Enterprise Ops") -or ($global:User_Properties.department -eq "Enterprise Systems")){ $user_department = "11307" }
If($global:User_Properties.department -eq "Facilities"){ $user_department = "11403" }
If(($global:User_Properties.department -eq "Human Resources") -or ($global:User_Properties.department -eq "HR")){ $user_department = "11306" }
If($global:User_Properties.department -eq "Licensing"){ $user_department = "11400" }
If($global:User_Properties.department -eq "QA"){ $user_department = "11308" }
If(($global:User_Properties.department -eq "Revenue Accounting") -or ($global:User_Properties.department -eq "Finanace")){ $user_department = "11305" }
If($global:User_Properties.department -eq "Sales"){
    If($global:User_Properties.title -like "*IFP*"){ $user_department = "11402" }
    If($global:User_Properties.title -like "*Medicare*"){ $user_department = "14390" }
    If($global:User_Properties.title -like "*SBG*"){ $user_department = "11309" }
}
If($global:User_Properties.department -eq "Training"){ $user_department = "11500" }
If(!$user_department){ $user_department = "13051" }

    
# Open browser and wait for it to load    
$browser.navigate2($website)
$browser.visible = $true
Wait-Loop -LookForTag "input" -LookForID "login" -LookForText "Log In"
Wait-Loop -LookForTag "a" -LookForID "forgotpassword" -LookForText "Can`'t access your account?"

# Being login process    
$pagecontent = $browser.Document
$ElementList = $pagecontent.getElementsByTagName("input")
ForEach($tag in $ElementList){
    If($tag.id -ne $null){
        If($tag.id -eq "login-form-username"){ $userfield = $tag }
        If($tag.id -eq "login-form-password"){ $pwdfield = $tag }
        If($tag.id -eq "login"){ $btn = $tag }
    }
}

Try{ 
    $userfield.value = $global:stored_username
    $pwdfield.value = $global:stored_password
    $btn.disabled = $false
    $btn.click()
}
Catch{ 
    Continue
}

# Check for login error
Do{
    Start-Sleep -Milliseconds 1200
    $pagecontent = $browser.Document
    $errorElements = $pageContent.GetElementsbyTagName("div")
    ForEach($tag in $errorElements){
        If($tag.id -ne $null){
            If($tag.id -eq "usernameerror"){
                $login_error = $true
                $browser.quit()
            }
        }
    }
    If($login_error -eq $true){
        $wshell = New-Object -ComObject WScript.Shell
        $wshell.Popup("Incorrect username or password.",0,"Error",0 + 48)
        # Login retry
        CredentialPrompt
            # Re-define browser object
            $website = "https://jira.ehealthinsurance.com/secure/Dashboard.jspa"
            $browser = New-Object -ComObject "InternetExplorer.Application"
            
            # Open browser and wait for it to load    
            $browser.navigate2($website)
            $browser.visible = $true
            Wait-Loop -LookForTag "input" -LookForID "login" -LookForText "Log In"

            # Being login process    
            $pagecontent = $browser.Document
            $ElementList = $pagecontent.getElementsByTagName("input")
            ForEach($tag in $ElementList){
                If($tag.id -ne $null){
                    If($tag.id -eq "login-form-username"){ $userfield = $tag }
                    If($tag.id -eq "login-form-password"){ $pwdfield = $tag }
                    If($tag.id -eq "login"){ $btn = $tag }
                }
            }

            Try{ 
                $userfield.value = $stored_username
                $pwdfield.value = $stored_password
                $btn.disabled = $false
                $btn.click()
            }
            Catch{ 
                $browser.quit()
                Exit
            }
    }
    Else{ $exitFlag = $true }
    $attempts++
    If($attempts -gt "3"){
        $browser.quit()
        $wshell.Popup("Your account may be locked out. Please consult your local administrator.",0,"Error",0 + 16)
        Exit
    }
    $login_error = $false
} Until($exitFlag)

# Wait for page to load and get new content
Wait-Loop -LookForTag "a" -LookForID "create_link" -LookForText "Create"
$pagecontent = $browser.Document
$ElementList = $pagecontent.getElementsByTagName("a")
ForEach($tag in $ElementList){
    If($tag.id -ne $null){
        If($tag.id -contains "create_link"){ $create = $tag }
    }
}
Do{
    $Problem = $false
    Try{
        $create.disabled = $false
        $create.click()
    }
    Catch{ $Problem = $true }
} Until($Problem -eq $false)

# Wait for creation prompt and get new content
Wait-Loop -LookForTag "input" -LookForID "create-issue-submit" -LookForText "Create"
$pagecontent = $browser.Document
$InputList = $pagecontent.getElementsByTagName("input")
ForEach($tag in $InputList){
    If($tag.id -ne $null){
        If($tag.id -eq "project"){ $ProjectType = $tag }
    }
}

# Check the project type before trying to apply information
If($ProjectType.value -ne "10060"){
    $Dropdown_List = $pagecontent.GetElementById("project-single-select")
    ForEach($item in $Dropdown_List.childNodes){
        If($item.tagname -eq "span"){ $item.click() }
    }
    Wait-Loop -LookForTag "div" -LookForID "project-suggestions" -LookForText "All Projects"
    $Options_Available = $pagecontent.GetElementById("all-projects")
    ForEach($tag in $Options_Available.childNodes){
        If($tag.id -match '(rfs)'){ $tag.click() }
    }
    Start-Sleep -Milliseconds 500
}

Do{
    Start-Sleep -Milliseconds 100
    $TagCheckList = (($browser.Document).getElementsbyTagName("div"))
    ForEach($tag in $TagCheckList){
        If($tag.id -ne $null){
            If($tag.id -eq "components-multi-select"){ $components_present = $tag }
        }
    }
    ForEach($item in $components_present.childNodes){
        If($item.tagname -eq "span"){ $comparison_text = $item.innerText }
    }
    If($comparison_text -like "*More*"){ $form_changed = $true }
} Until($form_changed)

# Define page input variables
$pagecontent = $browser.Document
$InputList = $pagecontent.getElementsByTagName("input")
ForEach($tag in $InputList){
    If($tag.id -ne $null){
        If($tag.id -eq "issuetype"){ $IssueType = $tag }
        If($tag.id -eq "customfield_10445"){ $SystemName = $tag }
        If($tag.id -eq "summary"){ $Summary = $tag }
        If($tag.id -eq "create-issue-submit"){ $Submit = $tag }
    }
}
$SelectList = $pagecontent.getElementsByTagName("select")
ForEach($tag in $SelectList){
    If($tag.id -ne $null){
        If($tag.id -eq "customfield_10001"){ $SeverityField = $tag }
        If($tag.id -eq "security"){ $SecurityField = $tag }
        If($tag.id -eq "customfield_10441"){ $Department = $tag }
    }
}

# Handle null values
If(!$global:users_software){ $global:users_software = "*User did not provide input*" }
If(!$global:software_need){ $global:software_need = "*User did not provide input*" }
If(!$global:user_description){ $global:user_description = "*User did not provide input*" }

# Combine information before input
If($global:users_issue -eq "Need Software Installed"){ $ticket = $global:users_issue }
Else{ $ticket = "$global:users_issue Issue" }
If(($global:users_issue -eq "Hardware") -or ($global:users_issue -eq "Software")){
    $Description = "This ticket was automatically generated with a user request tool. All information provided is relevant at the time of this ticket's creation.`
    `
    - Affected user(s): $global:selected_user `
    - Is this a reoccurring issue? $global:recurrence_choice `
    - Machine has been online since: $uptime `
    `
    +User description of the issue:+ $global:user_description `
    `
    Please annotate any and all troubleshooting actions taken in the comments section below."
}
If($global:users_issue -eq "Need Software Installed"){
    $Description = "This ticket was automatically generated with a user request tool. All information provided is relevant at the time of this ticket's creation.`
    `
    - Affected user(s): $global:selected_user `
    - Name of software: $global:users_software `
    `
    +User's business need for the software:+ $global:software_need `
    `
    Please annotate approvals and escalations in the comments section below."
}
If($global:users_issue -eq "General/Unknown"){
    $Description = "This ticket was automatically generated with a user request tool. All information provided is relevant at the time of this ticket's creation.`
    `
    - The user has signified that they do not know the root cause of the issue or that other ticket types do not sufficiently convey their needs. `
    - Affected user(s): $global:selected_user `
    - Machine has been online since: $uptime `
    `
    +User description:+ $global:user_description `
    `
    Please annotate all actions taken in the comments section below."
}

# Input information into the defined fields
Do{
    $Problem = $false
    Try{
        $IssueType.Value = "38"
        $SeverityField.Value = "10881"
        $Department.Value = $user_department
        $Component = $pagecontent.getElementsByTagName("option")
            ForEach($tag in $Component){
                If($tag.value -eq $local){ $tag.Selected = $true }
            }
        $SystemName.Value = $global:users_computername
        ForEach($option in $SecurityField.childNodes){
            If($option.value -eq "-1"){ $option.Selected = $true }
        }
        $Summary.Value = (($ticket)+" - "+(get-date -format (("MMM dd, yyy")+" "+("HH:mm:ss"))))
        $TextArea = $pagecontent.getElementsbyTagName("textarea")
            ForEach($tag in $TextArea){
                If($tag.id -ne $null){
                    If($tag.id -eq "description"){ $tag.innerText = $Description }
                }
            }
     }
     Catch{ $Problem = $true }
} Until($Problem -eq $false)

# Submit the Issue and close the browser
Start-Sleep -seconds 2
$Submit.click()
Start-Sleep -seconds 2
$browser.quit()

[System.Runtime.Interopservices.Marshal]::ReleaseComObject($browser)
