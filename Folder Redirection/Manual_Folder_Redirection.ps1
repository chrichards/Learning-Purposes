# Verify no one is logged in
$UserSessionID = ((quser | Where {$_ -match "console"}) -Split ' +')[3]
Start-Process cmd -ArgumentList '/c',"Logoff $UserSessionID" -Wait -ErrorAction SilentlyContinue

# Make sure the Max runtime GPO is in place
If((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System").MaxGPOScriptWait -eq $null){
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "MaxGPOScriptWait" -Value "0" -PropertyType DWORD -Force
}
Else{
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "MaxGPOScriptWait" -Value "0" -Force
}
##########################################################################################################################################

# Adjust Local GP Objects
$CSEUserExtensionGUID = "{42B5FAAE-6536-11D2-AE5A-0000F87571E3}"
$ToolExtensionUserGUID = "{40B66650-4972-11D1-A7CA-0000F87571E3}"
$UserPolicyIncrement = "131072"
$ComputerPolicyIncrement = "1"
$GroupPolicy = "$env:WINDIR\System32\GroupPolicy\"
$Contents = @()

If(Test-Path "$GroupPolicy\gpt.ini"){
    If(-Not(Test-Path "$GroupPolicy\User\Scripts")){ 
        New-Item -Path "$GroupPolicy\User" -Name "Scripts" -ItemType Directory -Force
        New-Item -Path "$GroupPolicy\User\Scripts" -Name "Logoff" -ItemType Directory -Force
        New-Item -Path "$GroupPolicy\User\Scripts" -Name "Logon" -ItemType Directory -Force
        Out-File "$GroupPolicy\User\Scripts\psscripts.ini" -Encoding unicode -Force
        Out-File "$GroupPolicy\User\Scripts\scripts.ini" -Encoding unicode -Force
        Get-Item "$GroupPolicy\User\Scripts\psscripts.ini" | %{$_.Attributes="hidden"}
        Get-Item "$GroupPolicy\User\Scripts\scripts.ini" | %{$_.Attributes="hidden"}
    }
    Clear-Content -Path "$GroupPolicy\gpt.ini"
    $GPTFile = Get-Content "$GroupPolicy\gpt.ini"
    ForEach($line in $GPTFile){
        If($line -eq "[General]"){ $Contents += $line; $General = $true }
        Else{ 
            If($line.Split('=')[0] -match "gPCFunctionalityVersion"){ $Functionality = $true }
            If($line.Split('=')[0] -match "gPCMachineExtensionNames"){ $MachineExtensionNames = $true }
            If($line.Split('=')[0] -match "Version"){ $line.Split('=')[1] = ($line.Split('=')[1] + $UserPolicyIncrement); $Version = $true }
            If($line.Split('=')[0] -match "gPCUserExtensionNames"){
                If(($line.Split('=')[1]).Trim() -eq ""){ $line.Split('=')[1] = "[$CSEUserExtensionGuid$ToolExtensionUserGUID]"; $UserExtensionNames = $true }
                Else{
                    If(($line.Split('=')[1] -match $CSEUserExtensionGUID) -and ($line.Split('=')[1] -match $ToolExtensionUserGUID)){ $UserExtensionNames = $true }
                    Else{
                        If($line.Split('=')[1] -notmatch $CSEUserExtensionGUID){ $line.Split('=')[1] = ($line.Split('=')[1]).Replace("]","$CSEUserExtensionGUID]"); $UserExtensionNames = $true }
                        If($line.Split('=')[1] -notmatch $ToolExtensionUserGUID){ $line.Split('=')[1] = ($line.Split('=')[1]).Replace("]","$ToolExtensionUserGUID]"); $UserExtensionNames = $true }
                    }
                }
            }
            If($line.Split('=')[0] -match "Options"){
                If(($line.Split('=')[1] -eq "0") -or ($line.Split('=')[1] -eq "2")){ $Option = $true }
                Else{
                    If($line.Split('=')[1] -eq "1"){ $line.Split('=')[1] = "0"; $Option = $true }
                    If($line.Split('=')[1] -eq "3"){ $line.Split('=')[1] = "2"; $Option = $true }
                }
            }
            $Contents += ($line.Split('=')[0] + "=" + $line.Split('=')[1])
        }
    }
    If($GPTFile.Length -eq 0){
        If($General -ne $true){ $Contents = ("[General]" + "`r`n") }
        If($Functionality -ne $true){ $Contents = ($Contents + "gPCFunctionalityVersion=2" + "`r`n") }
        If($MachineExtensionNames -ne $true){ $Contents = ($Contents + "gPCMachineExtensionNames=[{35378EAC-683F-11D2-A89A-00C04FBBCFA2}{0F6B957D-509E-11D1-A7CC-0000F87571E3}]" + "`r`n") }
        If($Version -ne $true){ $Contents = ($Contents + "Version=131073" + "`r`n") }
        If($UserExtensionNames -ne $true){ $Contents = ($Contents + "gPCUserExtensionNames=[$CSEUserExtensionGUID$ToolExtensionUserGUID]" + "`r`n") }
        If($Option -ne $true){ $Contents = ($Contents + "Options=0") }
    }
    Else{
        If($General -ne $true){ $Contents = ("[General]" + "`r`n") }
        If($Functionality -ne $true){ $Contents = ($Contents + "gPCFunctionalityVersion=2") }
        If($MachineExtensionNames -ne $true){ $Contents = ($Contents + "gPCMachineExtensionNames=[{35378EAC-683F-11D2-A89A-00C04FBBCFA2}{0F6B957D-509E-11D1-A7CC-0000F87571E3}]") }
        If($Version -ne $true){ $Contents = ($Contents + "Version=131073") }
        If($UserExtensionNames -ne $true){ $Contents = ($Contents + "gPCUserExtensionNames=[$CSEUserExtensionGUID$ToolExtensionUserGUID]") }
        If($Option -ne $true){ $Contents = ($Contents + "Options=0") }
    }

    Set-Content -Path "$GroupPolicy\gpt.ini" -Value $Contents
}
Else{
    $Contents = '[General]
gPCFunctionalityVersion=2
gPCMachineExtensionNames=[{35378EAC-683F-11D2-A89A-00C04FBBCFA2}{0F6B957D-509E-11D1-A7CC-0000F87571E3}]
Version=131073
gPCUserExtensionNames=[{42B5FAAE-6536-11D2-AE5A-0000F87571E3}{40B66650-4972-11D1-A7CA-0000F87571E3}]
Options=0'
    
    Set-Content -Path "$GroupPolicy\gpt.ini" -Value $Contents -Encoding ASCII
}
If(Test-Path "$GroupPolicy\User\Scripts\psscripts.ini"){
    $psscript = Get-Item "$GroupPolicy\User\Scripts\psscripts.ini" -Force
    
    $Contents = '[Logon]
[Logoff]
0CmdLine=C:\Support_Tools\FR\Migration.ps1
0Parameters='

    Set-Content -Path "$GroupPolicy\User\Scripts\psscripts.ini" -Value $Contents
}
##########################################################################################################################################

# Create scheduled task on user's machine
# Task will trigger on logon of any user
$ShedService = New-Object -COM 'Schedule.Service'
$ShedService.Connect()

$Task = $ShedService.NewTask(0)
$Task.RegistrationInfo.Description = 'Create a user-based task schedule'
$Task.Settings.Enabled = $true
$Task.Settings.Hidden = $true
$Task.Settings.AllowDemandStart = $true

$trigger = $task.triggers.Create(9)
$trigger.Enabled = $true

$action = $Task.Actions.Create(0)
$action.Path = 'Powershell.exe'
$action.Arguments = '-ExecutionPolicy Bypass -WindowStyle hidden C:\Support_Tools\FR\MakeUserTask.ps1'

$taskFolder = $ShedService.GetFolder("\")
$taskFolder.RegisterTaskDefinition('MakeUserTask', $Task , 6, 'Users', $null, 4)
##########################################################################################################################################

# Create scheduled task on user's machine
# Task will trigger on startup of the computer
$ShedService = New-Object -COM 'Schedule.Service'
$ShedService.Connect()

$Task = $ShedService.NewTask(0)
$Task.RegistrationInfo.Description = 'Create a startup-based task'
$Task.Settings.Enabled = $true
$Task.Settings.Hidden = $true
$Task.Settings.AllowDemandStart = $true

$trigger = $task.triggers.Create(8)
$trigger.Enabled = $true

$action = $Task.Actions.Create(0)
$action.Path = 'Powershell.exe'
$action.Arguments = '-ExecutionPolicy Bypass -WindowStyle hidden C:\Support_Tools\FR\Cleanup.ps1'

$taskFolder = $ShedService.GetFolder("\")
$taskFolder.RegisterTaskDefinition('OnStartup', $Task , 6, 'System', $null, 5)
##########################################################################################################################################

# User-based scheduled task digest
# User's scheduled task will trigger script to create FR Folders while
# user is logged in
$MakeUserTask = @'
$ShedService = New-Object -COM 'Schedule.Service'
$ShedService.Connect()

$Task = $ShedService.NewTask(0)
$Task.RegistrationInfo.Description = 'Create user FR folders'
$Task.Settings.Enabled = $true
$Task.Settings.Hidden = $true
$Task.Settings.AllowDemandStart = $true

$trigger = $task.triggers.Create(1)
$addtime = (Get-Date).AddMinutes(2).ToString("yyyy-MM-ddTHH:mm:ss")
$trigger.StartBoundary = $addtime
$trigger.Enabled = $true

$action = $Task.Actions.Create(0)
$action.Path = 'Powershell.exe'
$action.Arguments = '-ExecutionPolicy Bypass -WindowStyle hidden C:\Support_Tools\FR\MakeFRFolders.ps1'

$user = "EHI\$env:username"
$taskFolder = $ShedService.GetFolder("\")
$taskFolder.RegisterTaskDefinition('MakeFRFolders', $Task , 6, $user, $null, 0)

Start-Process cmd -ArgumentList '/c','gpupdate /force' -Wait -WindowStyle hidden
'@
##########################################################################################################################################

# Script that creates FR Folders without needing FR policy in place
$MakeFRFolders = @'
# Timestamp
$Timestamp = (Get-Date -f hh:mm:ss)

# Create log file
Start-Transcript -Path "$env:windir\Temp\FolderRedirect.log" -Append -IncludeInvocationHeader

# Determine which file server to use
$IP = ((ipconfig |findstr [0-9].\.)[0]).split()[-1]
If($IP -like “#.#.*”){
    $FileServer = "\\FileServer1\FileShare$"
}
If($IP -like “#.#.*”){
    $FileServer = "\\FileServer2\FileShare$"
}
Write-Host $Timestamp " - $user folders will be created in $FileServer"

# Define the user
$user = $env:USERNAME

# Create $user's Folder Redirection folders
Write-Host $Timestamp " - Attempting to create $user's FR directory..."
If(Test-Path ("$FileServer\$user")){ 
    Write-Host $Timestamp " - $user's directory already exists! Checking for other folders..."
    If(Test-Path ("$FileServer\$user\Contacts")){ Write-Host $Timestamp " - Contacts folder already exists! Skipping..." }
    Else{
        Try{ 
            New-Item -Path "$FileServer\$user" -Name "Contacts" -ItemType Directory -Force -ErrorAction Stop
            Write-Host $Timestamp " - Successfully created Contacts folder."
        }
        Catch{
            Write-Host $_.Exception.Message 
            Write-Host $Timestamp " - Unable to create Contacts folder."
            $ErrorOccurred = $true
        } 
    }
    If(Test-Path ("$FileServer\$user\Desktop")){ Write-Host $Timestamp " - Desktop folder already exists! Skipping..." }
    Else{
        Try{ 
            New-Item -Path "$FileServer\$user" -Name "Desktop" -ItemType Directory -Force -ErrorAction Stop
            Write-Host $Timestamp " - Successfully created Desktop folder."
        }
        Catch{
            Write-Host $_.Exception.Message 
            Write-Host $Timestamp " - Unable to create Desktop folder."
            $ErrorOccurred = $true
        } 
    }
    If(Test-Path ("$FileServer\$user\Favorites")){ Write-Host $Timestamp " - Favorites folder already exists! Skipping..." }
    Else{
        Try{ 
            New-Item -Path "$FileServer\$user" -Name "Favorites" -ItemType Directory -Force -ErrorAction Stop
            Write-Host $Timestamp " - Successfully created Favorites folder."
        }
        Catch{
            Write-Host $_.Exception.Message
            Write-Host $Timestamp " - Unable to create Favorites folder."
            $ErrorOccurred = $true
        } 
    }
    If(Test-Path ("$FileServer\$user\Links")){ Write-Host $Timestamp " - Links folder already exists! Skipping..." }
    Else{
        Try{ 
            New-Item -Path "$FileServer\$user" -Name "Links" -ItemType Directory -Force -ErrorAction Stop
            Write-Host $Timestamp " - Successfully created Links folder."
        }
        Catch{
            Write-Host $_.Exception.Message
            Write-Host $Timestamp " - Unable to create Links folder."
            $ErrorOccurred = $true
        } 
    }
    If(Test-Path ("$FileServer\$user\Documents")){ Write-Host $Timestamp " - Documents folder already exists! Skipping..." }
    Else{
        Try{ 
            New-Item -Path "$FileServer\$user" -Name "Documents" -ItemType Directory -Force -ErrorAction Stop
            Write-Host $Timestamp " - Successfully created Documents folder."
        }
        Catch{
            Write-Host $_.Exception.Message
            Write-Host $Timestamp " - Unable to create Documents folder."
            $ErrorOccurred = $true
        } 
    }
    If(Test-Path ("$FileServer\$user\Pictures")){ Write-Host $Timestamp " - Pictures folder already exists! Skipping..." }
    Else{
        Try{ 
            New-Item -Path "$FileServer\$user" -Name "Pictures" -ItemType Directory -Force -ErrorAction Stop
            Write-Host $Timestamp " - Successfully created Pictures folder."
        }
        Catch{
            Write-Host $_.Exception.Message
            Write-Host $Timestamp " - Unable to create Pictures folder."
            $ErrorOccurred = $true
        } 
    }
}
Else{
    Try{
        New-Item -Path "$FileServer" -Name "$user" -ItemType Directory -Force -ErrorAction Stop
        Write-Host $Timestamp " - Successfully created $user folder."
    }
    Catch{
        Write-Host $_.Exception.Message
        Write-Host $Timestamp " - Unable to create $user folder."
        $CannotContinue = $true
    }
    If($CannotContinue -eq $null){
        Try{ 
            New-Item -Path "$FileServer\$user" -Name "Contacts" -ItemType Directory -Force -ErrorAction Stop
            Write-Host $Timestamp " - Successfully created Contacts folder."
        }
        Catch{
            Write-Host $_.Exception.Message 
            Write-Host $Timestamp " - Unable to create Contacts folder."
            $ErrorOccurred = $true
        } 
        Try{ 
            New-Item -Path "$FileServer\$user" -Name "Desktop" -ItemType Directory -Force -ErrorAction Stop
            Write-Host $Timestamp " - Successfully created Desktop folder."
        }
        Catch{
            Write-Host $_.Exception.Message 
            Write-Host $Timestamp " - Unable to create Desktop folder."
            $ErrorOccurred = $true
        } 
        Try{ 
            New-Item -Path "$FileServer\$user" -Name "Favorites" -ItemType Directory -Force -ErrorAction Stop
            Write-Host $Timestamp " - Successfully created Favorites folder."
        }
        Catch{
            Write-Host $_.Exception.Message
            Write-Host $Timestamp " - Unable to create Favorites folder."
            $ErrorOccurred = $true
        } 
        Try{ 
            New-Item -Path "$FileServer\$user" -Name "Links" -ItemType Directory -Force -ErrorAction Stop
            Write-Host $Timestamp " - Successfully created Links folder."
        }
        Catch{
            Write-Host $_.Exception.Message
            Write-Host $Timestamp " - Unable to create Links folder."
            $ErrorOccurred = $true
        } 
        Try{ 
            New-Item -Path "$FileServer\$user" -Name "Documents" -ItemType Directory -Force -ErrorAction Stop
            Write-Host $Timestamp " - Successfully created Documents folder."
        }
        Catch{
            Write-Host $_.Exception.Message
            Write-Host $Timestamp " - Unable to create Documents folder."
            $ErrorOccurred = $true
        } 
        Try{ 
            New-Item -Path "$FileServer\$user" -Name "Pictures" -ItemType Directory -Force -ErrorAction Stop
            Write-Host $Timestamp " - Successfully created Pictures folder."
        }
        Catch{
            Write-Host $_.Exception.Message
            Write-Host $Timestamp " - Unable to create Pictures folder."
            $ErrorOccurred = $true
        }
    }
}
If($ErrorOccurred -or $CannotContinue){ Write-Host $Timestamp " - Unable to create required folders. Stopping..."; Exit }

# Create local backups of Chrome bookmarks and Sticky Notes
If(Test-Path "$env:USERPROFILE\Documents\Chrome Bookmarks"){
    Write-Host $Timestamp " - Local backup folder for Chrome exists."
    Write-Host $Timestamp " - Copying $user's Chrome bookmarks to backup directory..."
    Try{ Copy-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Bookmarks*" "$env:USERPROFILE\Documents\Chrome Bookmarks" -Force -ErrorAction Stop }
    Catch{ Write-Host $_.Exception.Message }
}
Else{
    Write-Host $Timestamp " - Local backup folder for Chrome DOES NOT exist."
    Write-Host $Timestamp " - Creating backup folder and backing up $user's Chrome bookmarks..."
    Try{
        New-Item -ItemType Directory -Path "$env:USERPROFILE\Documents" -Name "Chrome Bookmarks" -Force -ErrorAction Stop
        Copy-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Bookmarks*" "$env:USERPROFILE\Documents\Chrome Bookmarks" -Force -ErrorAction Stop
    }
    Catch{ Write-Host $_.Exception.Message }
}

If(Test-Path "$env:APPDATA\Microsoft\Sticky Notes"){
    If(Test-Path "$env:USERPROFILE\Documents\Sticky Notes"){
        Write-Host $Timestamp " - Local backup folder for Sticky Notes exists."
        Write-Host $Timestamp " - Copying $user's Sticky Notes to backup directory..."
        Try{ Copy-Item "$env:APPDATA\Microsoft\Sticky Notes\StickyNotes.snt" "$env:USERPROFILE\Documents\Sticky Notes" -Force -ErrorAction Stop }
        Catch{ Write-Host $_.Exception.Message }
    }
    Else{
        Write-Host $Timestamp " - Local backup folder for Sticky Notes DOES NOT exist."
        Write-Host $Timestamp " - Creating backup folder and backing up $user's Sticky Notes..."
        Try{
            New-Item -ItemType Directory -Path "$env:USERPROFILE\Documents" -Name "Sticky Notes" -Force -ErrorAction Stop
            Copy-Item "$env:APPDATA\Microsoft\Sticky Notes\StickyNotes.snt" "$env:USERPROFILE\Documents\Sticky Notes" -Force -ErrorAction Stop
        }
        Catch{ Write-Host $_.Exception.Message }
    }
}

If(Test-Path "$env:APPDATA\Microsoft\Signatures"){
    If(Test-Path "$env:USERPROFILE\Documents\Signatures"){
        Write-Host $Timestamp " - Local backup folder for Signatures exists."
        Write-Host $Timestamp " - Copying $user's Signatures to backup directory..."
        Try{ Copy-Item "$env:APPDATA\Microsoft\Signatures" "$env:USERPROFILE\Documents\Signatures" -Recurse -Force -ErrorAction Stop }
        Catch{ Write-Host $_.Exception.Message }
    }
    Else{
        Write-Host $Timestamp " - Local backup folder for Signatures Notes DOES NOT exist."
        Write-Host $Timestamp " - Creating backup folder and backing up $user's Signatures..."
        Try{
            New-Item -ItemType Directory -Path "$env:USERPROFILE\Documents" -Name "Signatures" -Force -ErrorAction Stop
            Copy-Item "$env:APPDATA\Microsoft\Signatures" "$env:USERPROFILE\Documents\Signatures" -Recurse -Force -ErrorAction Stop
        }
        Catch{ Write-Host $_.Exception.Message }
    }
}
'@
##########################################################################################################################################

$Migration = @'
# Timestamp
$Timestamp = (Get-Date -f hh:mm:ss)

# Create log file
Start-Transcript -Path "$env:windir\Temp\FolderRedirect.log" -Append -IncludeInvocationHeader

# Get the most recently used profile as current user
$user = $env:USERNAME

# Function for creating a local backup of $user's files
Function Copy-WithProgress {
	[CmdletBinding()]
    Param(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)]$Source,
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)]$Destination
	)

	$Filelist = Get-Childitem $Source –Recurse
	$Total = $Filelist.Count
	$Position = 0
    Write-Host $Timestamp " - $Total files are being serviced. Please wait..."
	ForEach($File in $Filelist){
        $Filename = $File.Fullname.replace($Source,'')
		$DestinationFile = ($Destination + $Filename)
		Copy-Item $File.FullName -Destination $DestinationFile -Force -Verbose
        $PercentComplete = [math]::Round(($Position/$total)*100)
        If($PercentComplete -eq "100"){ Write-Host $Timestamp " - $Destination done." }
        $Position++
	}
}

# Check if proper directories exist and create backup
Write-Host $Timestamp " - Creating a local backup of $user's files."
If(Test-Path "C:\Support_Tools"){ 
    If(Test-Path "C:\Support_Tools\$user Backup"){
        Remove-Item "C:\Support_Tools\$user Backup" -Recurse -Force
        Copy-WithProgress -Source "C:\Users\$user" -Destination "C:\Support_Tools\$user Backup"
    }
    Else{ 
        New-Item -ItemType Directory -Path "C:\Support_Tools" -Name "$user Backup" | Out-Null 
        If(Test-Path "C:\Support_Tools\$user Backup"){
            Copy-WithProgress -Source "C:\Users\$user" -Destination "C:\Support_Tools\$user Backup"
        }
    }
}
Else{
    New-Item -ItemType Directory -Path "C:\" -Name "Support_Tools" | Out-Null
    New-Item -ItemType Directory -Path "C:\Support_Tools" -Name "$user Backup" | Out-Null
    If(Test-Path "C:\Support_Tools\$user Backup"){
        Copy-WithProgress -Source "C:\Users\$user" -Destination "C:\Support_Tools\$user Backup"
    }
}
Write-Host $Timestamp " - Backup complete! Files stored in C:\Support_Tools\$user Backup"

# Determine which file server to use
$IP = ((ipconfig |findstr [0-9].\.)[0]).split()[-1]
If($IP -like “#.#.*”){
    $FileServer = "\\FileServer1\FileShare$"
}
If($IP -like “#.#.*”){
    $FileServer = "\\FileServer2\FileShare$"
}
Write-Host $Timestamp " - $user folders will be created in $FileServer"

# Move files out of $user's directory and into proper folders
Try{ 
    $UserFiles = Get-ChildItem -Path "C:\Users\$user" -File -ErrorAction Stop
    $UserDirectories = Get-ChildItem -Path "C:\Users\$user" -Directory -ErrorAction Stop
}
Catch{ Write-Host $Timestamp " - Could not get $user's files from their local profile folder." }

If($UserFiles -eq $null){ Write-Host $Timestamp " - No files need to be moved." }
Else{
    Write-Host $Timestamp " - Moving files out of $user's local profile and into a correct location for FR..." 
    ForEach($File in $UserFiles){
        If(($File.Extension -eq ".png") -or ($File.Extension -eq ".jpg") -or ($File.Extension -eq ".gif")){ 
            Try{
                Write-Host $Timestamp " - Moving $File to Pictures..." 
                Move-Item -Path "C:\Users\$user\$File" -Destination "C:\Users\$user\Pictures" -Verbose -ErrorAction Stop
            }
            Catch{
                Write-Host $_.Exception.Message
                Write-Host $Timestamp " - Unable to move $File!"
                $FileMoveError = $true
            }
        }
        Else{
            Try{
                Write-Host $Timestamp " - Moving $File to My Documents..."
                Move-Item -Path "C:\Users\$user\$File" -Destination "C:\Users\$user\Documents" -Verbose -ErrorAction Stop
            }
            Catch{
                Write-Host $_.Exception.Message
                Write-Host $Timestamp " - Unable to move $File!"
                $FileMoveError = $true
            }
        }
    }
    Write-Host $Timestamp " - Moving folders out of $user's local profile and into a correct location for FR..."
}
If($UserDirectories -eq $null){ Write-Host $Timestamp " - No folders need to be moved." }
Else{
    $IgnoreFolders = @('Contacts','Desktop','Documents','Downloads','Favorites','Links','Music','Pictures','Saved Games','Searches','Videos')
    ForEach($Folder in $UserDirectories){
        If($Folder.Name -in $IgnoreFolders){ $Skip }
        Else{
            Try{
                Write-Host $Timestamp " - Moving $Folder to My Documents..."
                Move-Item -Path "C:\Users\$user\$Folder" -Destination "C:\Users\$user\Documents" -Verbose -ErrorAction Stop
            }
            Catch{
                    Write-Host $_.Exception.Message
                    Write-Host $Timestamp " - Unable to move $Folder!"
                    $FileMoveError = $true
            }
        }
    }
}
If($FileMoveError -eq $true){ Write-Host $Timestamp " - There was a problem in moving some of the user's files or folders! Please review the log." }

# Move all local files and folders to the FR folders
Write-Host $Timestamp " - Attempting to copy $user's files and folders to the $user's new FR folders..."
Try{
    Write-Host $Timestamp " - Moving $user's Contacts..."
    Copy-WithProgress -Source "C:\Users\$user\Contacts" -Destination "$FileServer\$user\Contacts" -ErrorAction Stop
    Write-Host $Timestamp " - $User's Contacts have been moved successfully!"
}
Catch{
    Write-Host $_.Exception.Message
    Write-Host $Timestamp " - Unable to move $user's Contacts!"
    $MovingError = $true
}
Try{
    Write-Host $Timestamp " - Moving $user's Desktop..."
    Copy-WithProgress -Source "C:\Users\$user\Desktop" -Destination "$FileServer\$user\Desktop" -ErrorAction Stop
    Write-Host $Timestamp " - $User's Desktop has been moved successfully!"
}
Catch{
    Write-Host $_.Exception.Message
    Write-Host $Timestamp " - Unable to move $user's Desktop!"
    $MovingError = $true
}
Try{
    Write-Host $Timestamp " - Moving $user's Favorites..."
    Copy-WithProgress -Source "C:\Users\$user\Favorites" -Destination "$FileServer\$user\Favorites" -ErrorAction Stop
    Write-Host $Timestamp " - $User's Favorites have been moved successfully!"
}
Catch{
    Write-Host $_.Exception.Message
    Write-Host $Timestamp " - Unable to move $user's Favorites!"
    $MovingError = $true
}
Try{
    Write-Host $Timestamp " - Moving $user's Links..."
    Copy-WithProgress -Source "C:\Users\$user\Links" -Destination "$FileServer\$user\Links" -ErrorAction Stop
    Write-Host $Timestamp " - $User's Links have been moved successfully!"
}
Catch{
    Write-Host $_.Exception.Message
    Write-Host $Timestamp " - Unable to move $user's Links!"
    $MovingError = $true
}
Try{
    Write-Host $Timestamp " - Moving $user's My Documents..."
    Copy-WithProgress -Source "C:\Users\$user\Documents" -Destination "$FileServer\$user\Documents" -ErrorAction Stop
    Write-Host $Timestamp " - $User's My Documents have been moved successfully!"
}
Catch{
    Write-Host $_.Exception.Message
    Write-Host $Timestamp " - Unable to move $user's My Documents!"
    $MovingError = $true
}
Try{
    Write-Host $Timestamp " - Moving $user's My Pictures..."
    Copy-WithProgress -Source "C:\Users\$user\Pictures" -Destination "$FileServer\$user\Pictures" -ErrorAction Stop
    Write-Host $Timestamp " - $User's My Pictures have been moved successfully!"
}
Catch{
    Write-Host $_.Exception.Message
    Write-Host $Timestamp " - Unable to move $user's My Pictures!"
    $MovingError = $true
}
If($MovingError -eq $true){Write-Host $Timestamp " - There are issues moving one or more of $user's folders. Please review the log." }

Write-Host $Timestamp " - Migration complete!"

New-Item -Path "C:\Support_Tools\FR" -Name "$user.txt"
'@
##########################################################################################################################################

# Cleanup script digest
$Cleanup = @'
# Timestamp
$Timestamp = (Get-Date -f hh:mm:ss)

# Determine which file server to use
$IP = ((ipconfig |findstr [0-9].\.)[0]).split()[-1]
If($IP -like “#.#.*”){
    $FileServer = "\\FileServer1\FileShare$"
}
If($IP -like “#.#.*”){
    $FileServer = "\\FileServer2\FileShare$"
}

# Define user
Do{
    $user_backup = Get-ChildItem -Path "C:\Support_Tools" | Where {$_.Name -like "*Backup"}
    If($user_backup -ne $null){
        $user = ($user_backup).Name -Replace " Backup",""
        $found = $true
    }
    Else{ Start-Sleep -Seconds 60 }
}Until($found -eq $true)

# Wait for a file
Do{ Start-Sleep -Seconds 60 }Until(Test-Path "C:\Support_Tools\FR\$user.txt")

# Create log file
Start-Transcript -Path "$env:windir\Temp\FolderRedirect.log" -Append -IncludeInvocationHeader

# Wait 2 minutes for userprofile to finish logging off
Write-Host $Timestamp " - Waiting 2 minutes for the user profile to finish logging off..."
Start-Sleep -Seconds 120

# Free up the memory space
[GC]::Collect()

# If backup exists, remove the local user account
If(Test-Path "C:\Support_Tools\$user Backup"){
    Write-Host $Timestamp " - Local account $user will now be removed."
    Try{ 
        (Get-WMIObject -Class Win32_UserProfile | Where {$_.LocalPath -match "$user"}).Delete()
        Write-Host $Timestamp " - Local account $user has been deleted."
    }
    Catch{
        Write-Host $_.Exception.Message
        Write-Host $Timestamp " - Could not delete local account for $user. Please try again as a local admin to remove this account."
    }
}

# Delete remnant task schedules
If(Test-Path "C:\Windows\System32\Tasks"){
    $Tasks = Get-ChildItem -Path "C:\Windows\System32\Tasks"
    ForEach($Task in $Tasks){
        If($Task.Name -match "MakeUserTask"){ Remove-Item -Path $Task.Fullname -Force; Write-Host $Timestamp " - Removed scheduled task MakeUserTask." }
        If($Task.Name -match "MakeFRFolders"){ Remove-Item -Path $Task.Fullname -Force; Write-Host $Timestamp " - Removed scheduled task MakeFRFolders." }
        If($Task.Name -match "OnStartup"){ Remove-Item -Path $Task.Fullname -Force; Write-Host $Timestamp " - Removed scheduled task OnStartup." }
    }
}

Clear-Content -Path "C:\Windows\System32\GroupPolicy\gpt.ini"
Clear-Content -Path "C:\Windows\System32\GroupPolicy\User\Scripts\psscripts.ini" -Force

Stop-Transcript; Start-Sleep -Seconds 2

Start-Process powershell -ArgumentList {"Start-Sleep 30";"Remove-Item -Path C:\Support_Tools\FR -Recurse -Force"}

# Rename log file and make it available on the server
$Timestamp = (Get-Date -UFormat %m%d%Y)
Rename-Item -Path "$env:windir\Temp\FolderRedirect.log" -NewName "$user-$Timestamp.log"
Try{
    If(Test-Path "$FileServer\User Migration Logs"){
        Copy-Item -Path "$env:windir\Temp\$user-$Timestamp.log" -Destination "$FileServer\User Migration Logs\$user-$Timestamp.log" -ErrorAction Stop
    }
    Else{
        New-Item -Path "$FileServer" -Name "User Migration Logs" -ItemType Directory -ErrorAction Stop
        Copy-Item -Path "$env:windir\Temp\$user-$Timestamp.log" -Destination "$FileServer\User Migration Logs\$user-$Timestamp.log" -ErrorAction Stop
    }
}
Catch{ Exit }
'@
##########################################################################################################################################

# Re-start script digest
$Restarter = @'
# Determine which file server to use
$IP = ((ipconfig |findstr [0-9].\.)[0]).split()[-1]
If($IP -like “#.#.*”){
    $FileServer = "\\FileShare1\FileShare$"
}
If($IP -like “10.43.*”){
    $FileServer = "\\FileShare2\FileShare$"
}

# Define user
Do{
    $user_backup = Get-ChildItem -Path "C:\Support_Tools" | Where {$_.Name -like "*Backup"}
    If($user_backup -ne $null){
        $user = ($user_backup).Name -Replace " Backup",""
        $found = $true
    }
    Else{ Start-Sleep -Seconds 60 }
}Until($found -eq $true)

# Wait for a file
Do{ Start-Sleep -Seconds 60 }Until(Test-Path "C:\Support_Tools\FR\$user.txt")

If(Test-Path "C:\Program Files (x86)\PGP Corporation"){
    $PGP = "C:\Program Files (x86)\PGP Corporation\PGP Desktop\pgpwde.exe"
    Try{ Start-Process $PGP -ArgumentList '--admin-authorization --add-bypass --disk 0 --admin-passphrase <Password>' -Wait -ErrorAction Stop }
    Catch{ Write-Host $_.Exception.Message }
}
If(Test-Path "C:\Program Files\PGP Corporation"){
    $PGP = "C:\Program Files\PGP Corporation\PGP Desktop\pgpwde.exe"
    Try{ Start-Process $PGP -ArgumentList '--admin-authorization --add-bypass --disk 0 --admin-passphrase <Password>' -Wait -ErrorAction Stop }
    Catch{ Write-Host $_.Exception.Message }
}
Start-Process cmd -ArgumentList '/c','shutdown /r /t 0' -WindowStyle hidden
'@

If(Test-Path "C:\Support_Tools\FR"){ 
    $MakeUserTask | Out-File "C:\Support_Tools\FR\MakeUserTask.ps1"
    $MakeFRFolders | Out-File "C:\Support_Tools\FR\MakeFRFolders.ps1"
    $Migration | Out-File "C:\Support_Tools\FR\Migration.ps1" 
    $Cleanup | Out-File "C:\Support_Tools\FR\Cleanup.ps1"
    $Restarter | Out-File "C:\Support_Tools\FR\Restarter.ps1"
}
Else{ 
    New-Item -Path "C:\Support_Tools" -Name "FR" -ItemType Directory -Force
    $MakeUserTask | Out-File "C:\Support_Tools\FR\MakeUserTask.ps1" 
    $MakeFRFolders | Out-File "C:\Support_Tools\FR\MakeFRFolders.ps1"
    $Migration | Out-File "C:\Support_Tools\FR\Migration.ps1"
    $Cleanup | Out-File "C:\Support_Tools\FR\Cleanup.ps1"
    $Restarter | Out-File "C:\Support_Tools\FR\Restarter.ps1"
}
Start-Process powershell -ArgumentList 'C:\Support_Tools\FR\Restarter.ps1' -WindowStyle hidden
