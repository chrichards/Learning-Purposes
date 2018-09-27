# Define scoped variables
$script:save_directory = $null
$script:computers = @()
$script:check1 = $false # Chrome
$script:check2 = $false # Edge
$script:check3 = $false # Edge Adv
$script:check4 = $false # Firefox
$script:check5 = $false # IE

# Define partial path variables
$chrome_logs = "AppData\Local\Google\Chrome\User Data\Default"
$edge_logs = "AppData\Local\Microsoft\Windows\WebCache"
$edge_advanced_logs = "AppData\Local\Packages\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AC"
$firefox_logs = "AppData\Roaming\Mozilla\Firefox\Profiles"
$internet_explorer_logs = "AppData\Local\Microsoft\Windows\History"

# Function: Folder select dialogue
# Using private and abstract calls of .NET, build a new "Vista-based" select folder dialogue
# This function was written by Pete Gomersall, https://www.sapien.com/forums/viewtopic.php?t=8662
Function BuildDialog {
    $sourcecode = @"
using System;
using System.Windows.Forms;
using System.Reflection;
namespace FolderSelect
{
    public class FolderSelectDialog
    {
        System.Windows.Forms.OpenFileDialog ofd = null;
        public FolderSelectDialog()
        {
            ofd = new System.Windows.Forms.OpenFileDialog();
            ofd.Filter = "Folders|\n";
            ofd.AddExtension = false;
            ofd.CheckFileExists = false;
            ofd.DereferenceLinks = true;
            ofd.Multiselect = false;
        }
        public string InitialDirectory
        {
            get { return ofd.InitialDirectory; }
            set { ofd.InitialDirectory = value == null || value.Length == 0 ? Environment.CurrentDirectory : value; }
        }
        public string Title
        {
            get { return ofd.Title; }
            set { ofd.Title = value == null ? "Select a folder" : value; }
        }
        public string FileName
        {
            get { return ofd.FileName; }
        }
        public bool ShowDialog()
        {
            return ShowDialog(IntPtr.Zero);
        }
        public bool ShowDialog(IntPtr hWndOwner)
        {
            bool flag = false;

            if (Environment.OSVersion.Version.Major >= 6)
            {
                var r = new Reflector("System.Windows.Forms");
                uint num = 0;
                Type typeIFileDialog = r.GetType("FileDialogNative.IFileDialog");
                object dialog = r.Call(ofd, "CreateVistaDialog");
                r.Call(ofd, "OnBeforeVistaDialog", dialog);
                uint options = (uint)r.CallAs(typeof(System.Windows.Forms.FileDialog), ofd, "GetOptions");
                options |= (uint)r.GetEnum("FileDialogNative.FOS", "FOS_PICKFOLDERS");
                r.CallAs(typeIFileDialog, dialog, "SetOptions", options);
                object pfde = r.New("FileDialog.VistaDialogEvents", ofd);
                object[] parameters = new object[] { pfde, num };
                r.CallAs2(typeIFileDialog, dialog, "Advise", parameters);
                num = (uint)parameters[1];
                try
                {
                    int num2 = (int)r.CallAs(typeIFileDialog, dialog, "Show", hWndOwner);
                    flag = 0 == num2;
                }
                finally
                {
                    r.CallAs(typeIFileDialog, dialog, "Unadvise", num);
                    GC.KeepAlive(pfde);
                }
            }
            else
            {
                var fbd = new FolderBrowserDialog();
                fbd.Description = this.Title;
                fbd.SelectedPath = this.InitialDirectory;
                fbd.ShowNewFolderButton = false;
                if (fbd.ShowDialog(new WindowWrapper(hWndOwner)) != DialogResult.OK) return false;
                ofd.FileName = fbd.SelectedPath;
                flag = true;
            }
            return flag;
        }
    }
    public class WindowWrapper : System.Windows.Forms.IWin32Window
    {
        public WindowWrapper(IntPtr handle)
        {
            _hwnd = handle;
        }
        public IntPtr Handle
        {
            get { return _hwnd; }
        }

        private IntPtr _hwnd;
    }
    public class Reflector
    {
        string m_ns;
        Assembly m_asmb;
        public Reflector(string ns)
            : this(ns, ns)
        { }
        public Reflector(string an, string ns)
        {
            m_ns = ns;
            m_asmb = null;
            foreach (AssemblyName aN in Assembly.GetExecutingAssembly().GetReferencedAssemblies())
            {
                if (aN.FullName.StartsWith(an))
                {
                    m_asmb = Assembly.Load(aN);
                    break;
                }
            }
        }
        public Type GetType(string typeName)
        {
            Type type = null;
            string[] names = typeName.Split('.');

            if (names.Length > 0)
                type = m_asmb.GetType(m_ns + "." + names[0]);

            for (int i = 1; i < names.Length; ++i) {
                type = type.GetNestedType(names[i], BindingFlags.NonPublic);
            }
            return type;
        }
        public object New(string name, params object[] parameters)
        {
            Type type = GetType(name);
            ConstructorInfo[] ctorInfos = type.GetConstructors();
            foreach (ConstructorInfo ci in ctorInfos) {
                try {
                    return ci.Invoke(parameters);
                } catch { }
            }

            return null;
        }
        public object Call(object obj, string func, params object[] parameters)
        {
            return Call2(obj, func, parameters);
        }
        public object Call2(object obj, string func, object[] parameters)
        {
            return CallAs2(obj.GetType(), obj, func, parameters);
        }
        public object CallAs(Type type, object obj, string func, params object[] parameters)
        {
            return CallAs2(type, obj, func, parameters);
        }
        public object CallAs2(Type type, object obj, string func, object[] parameters) {
            MethodInfo methInfo = type.GetMethod(func, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            return methInfo.Invoke(obj, parameters);
        }
        public object Get(object obj, string prop)
        {
            return GetAs(obj.GetType(), obj, prop);
        }
        public object GetAs(Type type, object obj, string prop) {
           PropertyInfo propInfo = type.GetProperty(prop, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            return propInfo.GetValue(obj, null);
        }
        public object GetEnum(string typeName, string name) {
            Type type = GetType(typeName);
            FieldInfo fieldInfo = type.GetField(name);
            return fieldInfo.GetValue(null);
        }
    }
}
"@
    $assemblies = ('System.Windows.Forms', 'System.Reflection')
    Add-Type -TypeDefinition $sourceCode -ReferencedAssemblies $assemblies -ErrorAction STOP
}

BuildDialog # build the new dialogue in memory

# Function: Main window
Function MainWindow {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Log Collector"
    $form.Size = New-Object System.Drawing.Size(440,465)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'Fixed3D'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    # Labels for the form
    $label0 = New-Object System.Windows.Forms.Label
    $label0.Location = New-Object System.Drawing.Point(20,15)
    $label0.Size = New-Object System.Drawing.Size(80,20)
    $label0.Text = "Logs to collect:"
    $form.Controls.Add($label0)
    
    $label1 = New-Object System.Windows.Forms.Label
    $label1.Location = New-Object System.Drawing.Point(20,285)
    $label1.Size = New-Object System.Drawing.Size(120,20)
    $label1.Text = "Save Location:"
    $form.Controls.Add($label1)

    $label2 = New-Object System.Windows.Forms.Label
    $label2.Location = New-Object System.Drawing.Point(20,330)
    $label2.Size = New-Object System.Drawing.Size(375,40)
    $label2.Text = "NOTE: If left blank or path is unreachable, the default location is your desktop. A new folder will be created automatically."
    $form.Controls.Add($label2)

    $label3 = New-Object System.Windows.Forms.Label
    $label3.Location = New-Object System.Drawing.Point(190,15)
    $label3.Size = New-Object System.Drawing.Size(115,20)
    $label3.Text = "Computer(s):"
    $form.Controls.Add($label3)

    # Checkboxes for log select
    $checkbox0 = New-Object System.Windows.Forms.CheckBox
    $checkbox0.Location = New-Object System.Drawing.Point(23,40) #35
    $checkbox0.Size = New-Object System.Drawing.Size(115,20)
    $checkbox0.TabIndex = 0
    $checkbox0.Text = "Select All"
        $checkbox0.Add_Click({
            If($checkbox0.Checked -eq $true){
                $checkbox1.Checked = $true; $checkbox2.Checked = $true; $checkbox3.Checked = $true
                $checkbox4.Checked = $true; $checkbox5.Checked = $true
            }
            If($checkbox0.Checked -eq $false){
                $checkbox1.Checked = $false; $checkbox2.Checked = $false; $checkbox3.Checked = $false
                $checkbox4.Checked = $false; $checkbox5.Checked = $false
            }
        })
    $form.Controls.Add($checkbox0)

    $checkbox1 = New-Object System.Windows.Forms.CheckBox
    $checkbox1.Location = New-Object System.Drawing.Point(23,65)
    $checkbox1.Size = New-Object System.Drawing.Size(115,20)
    $checkbox1.TabIndex = 1
    $checkbox1.Text = "Chrome"
    $form.Controls.Add($checkbox1)

    $checkbox2 = New-Object System.Windows.Forms.CheckBox
    $checkbox2.Location = New-Object System.Drawing.Point(23,90)
    $checkbox2.Size = New-Object System.Drawing.Size(115,20)
    $checkbox2.TabIndex = 2
    $checkbox2.Text = "Edge"
    $form.Controls.Add($checkbox2)

    $checkbox3 = New-Object System.Windows.Forms.CheckBox
    $checkbox3.Location = New-Object System.Drawing.Point(23,115)
    $checkbox3.Size = New-Object System.Drawing.Size(115,20)
    $checkbox3.TabIndex = 3
    $checkbox3.Text = "Edge (Advanced)"
    $form.Controls.Add($checkbox3)

    $checkbox4 = New-Object System.Windows.Forms.CheckBox
    $checkbox4.Location = New-Object System.Drawing.Point(23,140)
    $checkbox4.Size = New-Object System.Drawing.Size(115,20)
    $checkbox4.TabIndex = 4
    $checkbox4.Text = "Firefox"
    $form.Controls.Add($checkbox4)

    $checkbox5 = New-Object System.Windows.Forms.CheckBox
    $checkbox5.Location = New-Object System.Drawing.Point(23,165)
    $checkbox5.Size = New-Object System.Drawing.Size(115,20)
    $checkbox5.TabIndex = 5
    $checkbox5.Text = "Internet Explorer"
    $form.Controls.Add($checkbox5)

    # Form buttons
        # Folder Select button
    $browseMenu = New-Object FolderSelect.FolderSelectDialog
    $browseMenu.Title = "Select a folder:"

    $browseButton = New-Object System.Windows.Forms.Button
    $browseButton.Location = New-Object System.Drawing.Point(322,303)
    $browseButton.Size = New-Object System.Drawing.Size(75,23)
    $browseButton.Text = "Browse..."
    $browseButton.TabIndex = 8
    $browseButton.Add_Click({
        $result = $browseMenu.ShowDialog()
        If($result -eq [System.Windows.Forms.DialogResult]::OK){
            $textbox0.Text = $browseMenu.FileName
        }
    })
    $form.Controls.Add($browseButton)

        # Run Button
    $runButton = New-Object System.Windows.Forms.Button
    $runButton.Location = New-Object System.Drawing.Point(133,378)
    $runButton.Size = New-Object System.Drawing.Size(75,23)
    $runButton.Text = "Run"
    $runButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $runButton.TabIndex = 9
    $form.Controls.Add($runButton)

        # Cancel Button
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(212,378)
    $cancelButton.Size = New-Object System.Drawing.Size(75,23)
    $cancelButton.Text = "Cancel"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cancelButton.TabIndex = 10
    $form.CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)

    # Text boxes for folder and computer input
        # This text box holds the directory where logs will be saved to
    $textbox0 = New-Object System.Windows.Forms.TextBox
    $textbox0.Location = New-Object System.Drawing.Point(23,305)
    $textbox0.Size = New-Object System.Drawing.Size(297,20)
    $textbox0.TabIndex = 7
    $form.Controls.Add($textbox0)

        # This box is where computer input will occur
    $textbox1 = New-Object System.Windows.Forms.RichTextBox
    $textbox1.Location = New-Object System.Drawing.Point(193,40)
    $textbox1.Size = New-Object System.Drawing.Size(205,235)
    $textbox1.TabIndex = 6
    $form.Controls.Add($textbox1)


    $result = $form.ShowDialog()
    
    If($result -eq [System.Windows.Forms.DialogResult]::OK){
        If($textbox0.Text -eq ""){$script:save_directory = "$env:USERPROFILE\Desktop"}
        Else{$script:save_directory = $textbox0.Text}
        
        $individual_computers = ($textbox1.Text).Split([Environment]::NewLine)
        ForEach($computer in $individual_computers){$script:computers += $computer}

        If($checkbox1.Checked -eq $true){$script:check1 = $true}
        If($checkbox2.Checked -eq $true){$script:check2 = $true}
        If($checkbox3.Checked -eq $true){$script:check3 = $true}
        If($checkbox4.Checked -eq $true){$script:check4 = $true}
        If($checkbox5.Checked -eq $true){$script:check5 = $true}
    }
    If($result -eq [System.Windows.Forms.DialogResult]::Cancel){
        Exit
    }
}

# Function: Show data processing
Function InfoWindow {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Log Collector"
    $form.Size = New-Object System.Drawing.Size(600,500)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'Fixed3D'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(20,15)
    $label.Size = New-Object System.Drawing.Size(100,20)
    $label.Text = "Logging:"
    $form.Controls.Add($label)

    $textbox = New-Object System.Windows.Forms.RichTextBox
    $textbox.Location = New-Object System.Drawing.Point(20,40)
    $textbox.Size = New-Object System.Drawing.Size(540,350)
    $textbox.ReadOnly = $true
    $form.Controls.Add($textbox)
    
    $form.Add_Shown({ProcessData})
    $result = $form.ShowDialog()

    If($result -eq [System.Windows.Forms.DialogResult]::Cancel){Exit}
}

# Function: Log collection process
Function ProcessData {
    # Timestamp format: day, month, year, hour, minute, second
    $timestamp = (Get-Date -Format ddMMyyyyhhmmss)
    $root = "$save_directory\Logs_$timestamp"

    Textbox_Output -Message "Making a new root directory to save files to."

    # Check for an existing root container. If it doesn't exist, make it
    If(Test-Path $root){
        $already_exists = $true
        Textbox_Output -Message "$root already exists. Using $root :"
    }
    Else{
        Try{New-Item -Path $save_directory -Name "Logs_$timestamp" -ItemType Directory -Force -Verbose -ErrorAction Stop}
        Catch{Add-Type -AssemblyName PresentationFramework;[System.Windows.MessageBox]::Show($_.Exception.Message,'Error'); Exit}
    }

    # Make a log file using Start-Transcript
    Start-Transcript -Path "$root\transactions_$timestamp.log" -Append -Force

    Textbox_Output -Message "Working directory is $root."
    Textbox_Output -Message "Begin processing.`r`n"

    # Process all the computers in $computers
    ForEach($computer in $computers){
        Try{Test-Connection $computer -Count 1 -ErrorAction Stop | Out-Null; $available = $true}
        Catch{$error = $_.Exception.Message; $available = $false}

        If($available -eq $true){
            Textbox_Output -Message "---------------------------------------------------------------------------------------------------"
            Textbox_Output -Message $computer
            Textbox_Output -Message "---------------------------------------------------------------------------------------------------"

            Try{New-Item -Path $root -Name $computer -ItemType Directory -Force -Verbose -ErrorAction Stop}
            Catch{Textbox_Output -Message $_.Exception.Message; Continue}

            # If the directory is made successfully, make a variable of it
            $working_path = "$root\$computer"

            # Collect information on what users are on the machine
            # Ignore folders for Administrator, Default, and Public
            $users = (Get-ChildItem -Path "\\$computer\c$\Users" -Exclude "Administrator","Public","Default").FullName
            Textbox_Output -Message "Processing $($users.Count) users on $computer..."

            # Set a variable for counting users
            # This is only meant to make the output text easier to navigate
            $i = 1

            # Process each of the users
            ForEach($user in $users){
                Textbox_Output -Message "######################   $i   ######################"
                $name = $user.Replace("\\$computer\c$\Users\","")

                Try{New-Item -Path $working_path -Name $name -ItemType Directory -Force -Verbose -ErrorAction Stop}
                Catch{Textbox_Output -Message $_.Exception.Message; Continue}

                $user_log_directory = "$working_path\$name"

                # Grab logs based on what was selected on MainScreen
                If($check1 -eq $true){
                    Textbox_Output -Message "Attempting to collect Chrome logs..."
                    If(Test-Path "$user\$chrome_logs"){
                        Try{New-Item -Path "$user_log_directory" -Name "Chrome" -ItemType Directory -Force -Verbose -ErrorAction Stop}
                        Catch{Textbox_Output -Message $_.Exception.Message}

                        If(Test-Path "$user_log_directory\Chrome"){
                            Try{
                                Copy-Item -Path "$user\$chrome_logs\History" -Destination "$user_log_directory\Chrome" -Force -Verbose -ErrorAction Stop
                                Textbox_Output -Message "`t`t`tSuccess!"
                            }
                            Catch{Textbox_Output -Message $_.Exception.Message}
                        }
                    }
                    Else{Textbox_Output -Message "`t`t`tNo logs for this user. Skipping."}
                }

                If($check2 -eq $true){
                    Textbox_Output -Message "Attempting to collect Edge logs..."
                    If(Test-Path "$user\$edge_logs"){
                        Try{New-Item -Path "$user_log_directory" -Name "Edge" -ItemType Directory -Force -Verbose -ErrorAction Stop}
                        Catch{Textbox_Output -Message $_.Exception.Message}

                        If(Test-Path "$user_log_directory\Edge"){
                            Try{
                                Copy-Item -Path "$user\$edge_logs\WebCacheV01.dat" -Destination "$user_log_directory\Edge" -Force -Verbose -ErrorAction Stop
                                Textbox_Output -Message "`t`t`tSuccess!"
                            }
                            Catch{Textbox_Output -Message $_.Exception.Message}
                        }
                    }
                    Else{Textbox_Output -Message "`t`t`tNo logs for this user. Skipping."}
                }

                If($check3 -eq $true){
                    Textbox_Output -Message "Attempting to collect Edge Advanced logs..."
                    If(Test-Path "$user\$edge_advanced_logs"){
                        Try{New-Item -Path "$user_log_directory" -Name "Edge-Advanced" -ItemType Directory -Force -Verbose -ErrorAction Stop}
                        Catch{Textbox_Output -Message $_.Exception.Message}

                        If(Test-Path "$user_log_directory\Edge-Advanced"){
                            Try{
                                Copy-Item -Path "$user\$edge_advanced_logs\*" -Destination "$user_log_directory\Edge-Advanced" -Force -Verbose -Recurse -ErrorAction Stop
                                Textbox_Output -Message "`t`t`tSuccess!"
                            }
                            Catch{Textbox_Output -Message $_.Exception.Message}
                        }
                    }
                    Else{Textbox_Output -Message "`t`t`tNo logs for this user. Skipping."}
                }

                If($check4 -eq $true){
                    Textbox_Output -Message "Attempting to collect Firefox logs..."
                    If(Test-Path "$user\$firefox_logs"){
                        Try{New-Item -Path "$user_log_directory" -Name "Firefox" -ItemType Directory -Force -Verbose -ErrorAction Stop}
                        Catch{Textbox_Output -Message $_.Exception.Message}

                        If(Test-Path "$user_log_directory\Firefox"){
                            $temp_logs = (Get-ChildItem -Path "$user\$firefox_logs" -Recurse -Filter "places.sqlite").FullName

                            If($temp_logs.Count -gt 1){
                                For($i=0;$i -lt $temp_logs.Count;$i++){
                                    Try{
                                        Copy-Item -Path $temp_logs[$i] -Destination "$user_log_directory\Firefox" -Force -Verbose -ErrorAction Stop
                                        Rename-Item -Path "$user_log_directory\Firefox\places.sqlite" -NewName "$iplaces.sqlite" -Force -Verbose -ErrorAction Stop
                                        Textbox_Output -Message "`t`t`t$i - Success!"
                                    }
                                    Catch{Textbox_Output -Message $_.Exception.Message}
                                }
                            }
                            Else{
                                Try{
                                    Copy-Item -Path $temp_logs -Destination "$user_log_directory\Firefox" -Force -Verbose -ErrorAction Stop
                                    Textbox_Output -Message "`t`t`tSuccess!"
                                }
                                Catch{Textbox_Output -Message $_.Exception.Message}
                            }
                        }
                    }
                    Else{Textbox_Output -Message "`t`t`tNo logs for this user. Skipping."}
                }

                If($check5 -eq $true){
                    Textbox_Output -Message "Attempting to collect Internet Explorer logs..."
                    If(Test-Path "$user\$internet_explorer_logs"){
                        Try{New-Item -Path "$user_log_directory" -Name "IE" -ItemType Directory -Force -Verbose -ErrorAction Stop}
                        Catch{Textbox_Output -Message $_.Exception.Message}

                        If(Test-Path "$user_log_directory\IE"){
                            Try{
                                Copy-Item -Path "$user\$internet_explorer_logs\*" -Destination "$user_log_directory\IE" -Force -Verbose -Recurse -ErrorAction Stop
                                Textbox_Output -Message "`t`t`tSuccess!"
                            }
                            Catch{Textbox_Output -Message $_.Exception.Message}
                        }
                    }
                    Else{Textbox_Output -Message "`t`t`tNo logs for this user. Skipping."}
                }

                $i++
            }
            Textbox_Output -Message "---------------------------------------------------------------------------------------------------`r`n"
            Textbox_Output -Message "`r`n"
        }
        ElseIf($available -eq $false){
            Textbox_Output -Message "---------------------------------------------------------------------------------------------------"
            Textbox_Output -Message $error
            Textbox_Output -Message "---------------------------------------------------------------------------------------------------`r`n"
            Textbox_Output -Message "`r`n"
        }
    }

    Textbox_Output -Message "Job complete.`r`n"
    Stop-Transcript
    Textbox_Output -Message "For more information, please see $root\transactions_$timestamp.log"
}

# Function: Message translation
# Allows for what's happening in ProcessData to be shown in InfoWindow
Function Textbox_Output {
    Param($Message)

    $textbox.AppendText("$Message`r")
    $textbox.ScrollToCaret()
    $textbox.Refresh()

    # Enable Start-Transcript to capture dialogue
    Write-Host $Message
}

# Start the user-driven segment
MainWindow

# If the user hasn't selected a checkbox, throw an error
Do{
    If(($check1 -ne $true) -and ($check2 -ne $true) -and ($check3 -ne $true) -and
    ($check4 -ne $true) -and ($check5 -ne $true)){
        $Message = "You must select at least one log type to collect."
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show($Message,'Error')
        $continue = $false
        MainWindow
    }
    Else{$continue = $true}
}Until($continue -eq $true)

# Show the logging window of what's being processed
InfoWindow
