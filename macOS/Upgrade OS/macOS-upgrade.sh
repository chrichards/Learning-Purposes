#!/bin/bash
# Version 3.16

# Variables
TargetName="$4"
TargetVersion="$5"
EraseOrUpgrade=$6
IFS=$'\n'
arch=$(/usr/bin/arch)

# The notifier
JamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

# Generic icons
WarnIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertNoteIcon.icns"
StopIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"


# Function to download and make latest OS available
DownloadOS() {

	if [[ -n $1 ]]; then
		echo "OS Download: OK - Using softwareupdate to get version $1 of macOS."
		softwareupdate --fetch-full-installer --full-installer-version $1 &> /private/tmp/macOS-upgrade.log &
		DownloaderPID=$!
	else
		echo "OS Download: OK - Using softwareupdate to get the latest version of macOS."
		softwareupdate --fetch-full-installer &> /private/tmp/macOS-upgrade.log &
		DownloaderPID=$!
	fi
		
	# Notification area so the user knows what's happening
	Displayed=""
	Message="Downloading the new OS - this may take a while"
	Title="Download Progress"
	/usr/bin/osascript -e 'display notification "'"$Message"'" with title "'"$Title"'"'
	
	while (ps ax | grep $DownloaderPID | grep -v grep) &> /dev/null; do
		ReadFile=$(cat /private/tmp/macOS-upgrade.log)
		if [[ "$ReadFile" =~ "Installing" ]]; then
			# I have NO idea why all the percentages dogpile on each other but this
			# is what needs to be done to pull them apart and get the ACTUAL last line
			Percent=$(echo "$ReadFile" | tail -1 | tr '[:space:]' '\n' | tail -1)
			Number=$(echo "$Percent" | cut -d"." -f1)
			
			if ((Number%3)); then
				# there's a remainder if divided by 5 so we'll skip
				continue
			else
				if [[ "$Number" == "$Displayed" ]]; then
					# we've already displayed this message so no need to show again
					continue
				else
					Message="Download $Percent complete"
					/usr/bin/osascript -e 'display notification "'"$Message"'" with title "'"$Title"'"'
					Displayed=$Number
				fi
			fi
		fi
		sleep 1
	done

	wait $DownloaderPID
	if [[ $? = 0 ]]; then
		echo "OS Download: OK - softwareupdate ran successfully."
	else
		echo "OS Download: ERROR - softwareupdate was unable to complete properly."
		exit 1
	fi
	
}

GetLatest() {

	# Apple Support URL for version info
	Url="https://support.apple.com/en-us/HT201260"

	# Can we actually access the site?
	ReturnCode=$(curl -s -I $Url | head -1 | awk '{print $2}')

	if [[ $ReturnCode = 200 ]]; then
		# Declare some arrays
		Titles=()
		Versions=()
		
		# What's the latest and greatest? Check the page!
		Page=$(curl -s $Url)
		
		# Parse for JUST the version table
		Table=($(echo $Page | awk '{gsub("> <",">\n<",$0); print}' | grep "<td>"))

		# Split the table into Titles and Versions
		for ((i=0; i<${#Table[@]}; i++)); do
			if [[ $(($i % 2)) == 0 ]]; then
				Titles+=($(echo "${Table[$i]}" | sed 's/<[^>]*>//g'))
			else
				Versions+=($(echo "${Table[$i]}" | sed 's/<[^>]*>//g'))
			fi
		done
		
		TargetName=${Titles[0]}
		LatestVersion=${Versions[0]}
		echo "Update Info: OK - Latest from Apple is $TargetName $LatestVersion"
	else
		echo "Update Info: ERROR - Could not verify information from Apple."
		exit 1
	fi
	
	echo "$TargetName:$LatestVersion"
}

Interpret_Input() {
	Interpreter=$1
	Part1=$(ioreg -l | grep IOPlatformSerialNumber | cut -d= -f2 | sed -e 's/[[:space:]"]//g')
	Part2=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; getline; print $NF}' | sed -e 's/[:]//g' | tr '[a-z]' '[A-Z]')
	Combo="$Part1$Part2"
	
	case $Interpreter in
		1)
			Input=$2
			Result=$(echo "$Input" | openssl enc -k "$(echo $Combo)" -md md5 -aes256 -base64 -e)
			;;
		2)
			Input=$(cat "$2")
			Result=$(echo "$Input" | openssl enc -k "$(echo $Combo)" -md md5 -aes256 -base64 -d)
			;;
	esac
	
	echo "$Result"
}

# What are we working with here?
arch=$(/usr/bin/arch)
if [[ "$arch" =~ "arm" ]]; then
	echo "CPU Architecture: Silicon"
	Type="Silicon"
elif [[ "$arch" == "i386" ]]; then
	echo "CPU Architecture: Intel"
	Type="Intel"
else
	# No idea how to handle this so we'll just exit
	echo "CPU Architecture: Unknown"
	echo "Unable to continue."
	# Give a unique exit code so we know -why- things failed
	exit 126
fi

# Line for reporting
echo "-------------------------"

# If it's Silicon, we need the user's password...
# Silicon Only: Check to see if user choice was ever offered
if [[ "$Type" == "Silicon" ]]; then
	# Define some user-based variables
	Username=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ {print $3}')
	if [[ ! -z "${Username// }" ]]; then
		Identifier=$(/usr/bin/dscl . -list /Users UniqueID | grep "$Username" | awk '{print $2}')
		echo "Silicon Only: $Username is logged in with ID $Identifier"
	else
		echo "Silicon Only: Can't continue the process because there's no user info."
		exit 1
	fi
	UserOptIn="/etc/security/$Identifier"
	
	# Before we can do anything, the user has to be identified as a token holder
	# If they don't have a token, they can't perform the upgrade
	if [[ $(sysadminctl -secureTokenStatus $Username 2>&1) =~ "ENABLED" ]]; then
		echo "Silicon Only: User has a SecureToken."
	else
		echo "Silicon Only: User does not have a SecureToken."
		echo "Silicon Only: Cannot continue with upgrade."
		Notification="You do not have a SecureToken assigned to your account. Please contact EUC to help with remediation."
		Title="macOS Upgrade Error"
		Choice=$(/usr/bin/osascript -e 'display dialog "'"$Notification"'" with title "'"$Title"'" with icon {"'"$StopIcon"'"} buttons {"OK"} default button 1')
		exit 1
	fi

	# Now we need to check for Volume Ownership
	DiskInfo=$(diskutil apfs listusers /)
	UserGUID=$(dscl . list /Users GeneratedUID | grep $Username | awk '{print $2}')
	VolumeOwner=$(echo "$DiskInfo" | grep $UserGUID -A 2)
	
	if [[ "$VolumeOwner" =~ "Yes" ]]; then
		# User is good to go
		echo "Silicon Only: User is a volume owner."
	else
		echo "Silicon Only: User is not a volume owner."
		echo "Silicon Only: Cannot continue with upgrade."
		Notification="You are not a volume owner for your system. Please contact EUC to help with remediation."
		Title="macOS Upgrade Error"
		Choice=$(/usr/bin/osascript -e 'display dialog "'"$Notification"'" with title "'"$Title"'" with icon {"'"$StopIcon"'"} buttons {"OK"} default button 1')
		exit 1
	fi
	
	if [ -f "$UserOptIn" ]; then
		echo "Silicon Only: User password file already exists."
		# User has saved their password at some point
		ContinueUpgrade="True"
		CheckValidity="True"
	else
		echo "Silicon Only: Presenting the user with prompt."
		# User has not received prompt; throw one out there
		Notification="Your password is required to authorize the upgrade process. Would you like to continue?"
		Title="Warning - Password Required"
		Choice=$(/usr/bin/osascript -e 'display dialog "'"$Notification"'" with title "'"$Title"'" with icon {"'"$WarnIcon"'"} with text buttons {"Yes","No"} default button "Yes"')
		
		if [[ "$Choice" =~ "No" ]]; then
			# User does not want to proceed
			echo "Silicon Only: User has selected no."
			Notification="You have chosen not to authorize the upgrade process. The upgrade will not happen at this time."
			/usr/bin/osascript -e 'display dialog "'"$Notification"'" with title "'"$Title"'" with icon {"'"$StopIcon"'"} with text buttons {"OK"}'
			exit 1
		elif [[ "$Choice" =~ "Yes" ]]; then
			# User has opted in! Yay!
			ContinueUpgrade="True"
		else
			echo "Silicon Only: Something went wrong and no choice was selected."
			exit 126
		fi
	fi
	
	if [[ "$ContinueUpgrade" == "True" ]]; then
		if [[ "$CheckValidity" == "True" ]]; then
			echo "Silicon Only: Checking stored password."
			Check=$(Interpret_Input 2 "$UserOptIn")
		else
			echo "Silicon Only: Retrieving the user's password."
			Check=$(osascript -e 'display dialog "Please enter your password:" with hidden answer default answer ""' -e 'text returned of result' 2>/dev/null)
		fi
		
		Authenticated="False"
		Count=1
		while [[ "$Authenticated" != "True" ]]; do
			PassCheck=$(dscl . authonly "$Username" "$Check" &> /dev/null; echo $?)

			if [ "$PassCheck" -eq 0 ]; then
				echo "Silicon Only: Password is good and can be used."
				# User has input the correct password
				Authenticated="True"
				(Interpret_Input 1 "$Check") > "$UserOptIn"
			elif [[ "$Count" > 3 ]]; then
				echo "Silicon Only: User failed to input their password properly 3 times"
				Notification="You have exceeded the maximum number of password attempts. Your system will not upgrade at this time."
				/usr/bin/osascript -e 'display dialog "'"$Notification"'" with title "'"$Title"'" with icon {"'"$StopIcon"'"} with text buttons {"OK"}'
				exit 1
			else
				echo "Silicon Only: Asking user to re-enter their password - attempt $Count"
				Check=$(/usr/bin/osascript -e 'display dialog "Please enter your password:" with hidden answer default answer ""' -e 'text returned of result' 2>/dev/null)
				Authenticated="False"
				((Count++))
			fi
		done
		unset Check
	fi
	
	# Elevate the user if they aren't an admin
	if [[ $(dscacheutil -q group -a name admin | grep $Username) ]]; then
		echo "Silicon Only: $Username is already an admin"
	else
		# create a flag file so we can remove the user later
		touch "/var/tmp/$Username"
		AdminFile="/var/tmp/$Username"
		dseditgroup -o edit -a $Username -t user admin
		echo "Silicon Only: $Username has been promoted to admin."
	fi
fi

# Is it an upgrade or a wipe/install?
# If it's not explicitly a wipe, it's implicitly an upgrade
if [[ $EraseOrUpgrade != 1 ]]; then
	EraseOrUpgrade=0
else
	# Really let the user know they're about to wipe the machine
	Title="WARNING"
	Message="You are about to perform an erase/upgrade. All files, applications, and data will be wiped from your system. Are you sure you want to continue?"
	/usr/bin/osascript -e 'display alert "'"$Title"'" message "'"$Message"'" as critical buttons {"Quit","Continue"} default button "Continue" cancel button "Quit"' &> /dev/null
	if [[ $? != 0 ]]; then
		echo "User Choice: ERROR - Upgrade did not continue."
		exit 1
	fi
fi

# Line for reporting
echo "-------------------------"

# First off, does the machine have the required space?
# Check for at least 20GB of free space
FreeSpaceInfo=$(diskutil info / | grep "Free Space")
FreeSpaceFloat=$(echo $FreeSpaceInfo | awk '{print $4}')
FreeSpaceSign=$(echo $FreeSpaceInfo | awk '{print $5}')
FreeSpaceBytes=$(echo $FreeSpaceInfo | awk '{print $6}' | sed 's/(//')

if [[ $FreeSpaceBytes -le $((40 * (1000**3))) ]]; then
	echo "Disk Check: ERROR - Only $FreeSpaceFloat $FreeSpaceSign free; not enough to continue upgrade."
	Message="Insufficient Free Space - You only have $FreeSpaceFloat $FreeSpaceSign available while the upgrade requires at least 40 GB."
	/usr/bin/osascript -e 'display dialog "'"$Message"'" with title "Not Enough Free Space" buttons {"OK"} default button 1' &> /dev/null
	exit 1
else
	echo "Disk Check: OK - $FreeSpaceFloat $FreeSpaceSign free; continuing upgrade."
fi

# Line for reporting
echo "-------------------------"

# If an OS version wasn't stipulated, get the latest
if [[ -z "$TargetVersion" ]]; then
	LatestOS=$(GetLatest)
	LatestName=$(echo "$LatestOS" | cut -d: -f1)
	LatestVersion=$(echo "$LatestOS" | cut -d: -f2)
	TargetName=$LatestName
	TargetVersion=$LatestVersion
	
	echo "OS Check: INFO - Target version was not specified"
	echo "OS Check: INFO - Getting $LatestName with version $LatestVersion"
fi
	
# Is there an installer already present?
# NOTE: While rare, it's possible to have *more than one* installer
# For that reason, the search is tossed into an array
OSInstaller=$(find /Applications -iname "Install macOS*" -maxdepth 1)

# There are no Install macOS apps in /Applications
if [[ -z "$OSInstaller" ]]; then
	DownloadOS $TargetVersion
	if [ -d "/Applications/Install $TargetName.app" ]; then
		echo "Installer Status: OK - $TargetName is ready to be installed."
		Installer="/Applications/Install $TargetName.app"
	else
		echo "Installer Status: ERROR - Unable to get $TargetName."
		exit 1
	fi
else
	# There's at least one installer to review
	for Installer in ${OSInstaller[@]}; do
		echo "Installer Status: INFO - Checking $Installer"
		InstallerInfoPlist=$(find $Installer -name "*Info*.plist" -maxdepth 2)
		InstallerName=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$InstallerInfoPlist")
		
		# To make sure we have the correct version, we've gotta go hunting WAY deep download
		# Open the Installer, attach a dmg, and then parse an xml; thanks, Apple!
		/usr/bin/hdiutil attach -noverify -quiet "$Installer/Contents/SharedSupport/SharedSupport.dmg"
		InstallerVersion=$(/usr/libexec/PlistBuddy -c 'Print :Assets:0:OSVersion' "/Volumes/Shared Support/com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml")
		/usr/bin/hdiutil detach -quiet "Volumes/Shared Support/"
		
		if [[ "$InstallerName" =~ "$TargetName" ]]; then
			if [[ "$InstallerVersion" == "$TargetVersion" ]]; then
				echo "Installer Status: OK - Reported version $InstallVersion matches the targeted version."
				echo "Installer Status: OK - $TargetName is ready to be installed."
				break
			else
				echo "Installer Status: WARN - Current installer with version $InstallerVersion needs to be replaced"
				/bin/rm -rf "$Installer"
				unset Installer
			fi
		else
			unset Installer
		fi
	done
	
	# If all of the installers are stale
	if [[ -z "$Installer" ]]; then
		echo "Installer Status: WARN - System does not have the required macOS installer."
		DownloadOS $TargetVersion
		if [ -d "/Applications/Install $TargetName.app" ]; then
			echo "Installer Status: OK - $TargetName is ready to be installed."
			Installer="/Applications/Install $TargetName.app"
		else
			echo "Installer Status: ERROR - Unable to get $TargetName."
			exit 1
		fi
	fi
fi

# Line for reporting
echo "-------------------------"

# Make sure the machine is plugged into AC power
# Wait for a max of 2 minutes before failing
Timer=0
while :; do
	PowerStatus=$(/usr/bin/pmset -g ps | head -1)
	if [[ "$PowerStatus" == *"AC Power"* ]]; then
		echo "Power Status: OK - Connected to AC power and ready to proceed with upgrade."
		break
	fi
	if [[ $Timer == 0 ]]; then
		"$JamfHelper" -windowType utility -title "Warning - Need AC Power" -icon $WarnIcon \
		-description "Please plug this computer into a power source. Upgrade will continue once AC power is detected." &
		PowerNotificationPID=$!
	fi
	if [[ $(($Timer % 30)) == 0 ]]; then
		echo "Power Status: WARN - Still waiting to be connected to AC power."
	elif [[ $Time == 120 ]]; then
		echo "Power Status: ERROR - No AC power detected; cannot continue upgrade."
		kill -9 $PowerNotificationPID
		exit 1
	fi
	sleep 1
	((Timer++))
done

# If the notification is still going for some reason, kill it
if [[ -n $PowerNotificationPID ]]; then
	kill -9 $PowerNotificationPID
fi

# Line for reporting
echo "-------------------------"

# Kill processes that aren't supposed to be running
Processes=$(ps -ax)
Targets=("caffeinate" "startosinstall" "osinstallersetup")
for Target in "${Targets[@]}"; do
	Check=$(echo "$Processes" | grep $Target)
	if [[ -n $Check ]]; then
		echo "Process Status: WARN - $Target is running and will be terminated."
		killall $Target
	fi
done

# User notification variables
InstallIcon="$Installer/Contents/Resources/InstallAssistant.icns"
echo "Installer Start: INFO - Checking for $InstallIcon"
if [ -f "$InstallIcon" ]; then
	echo "Installer Start: INFO - Icon exists."
else
	echo "Installer Start: INFO - No icon available!"
fi
Title="$TargetName Upgrade"
Heading="Please wait while we prepare your computer for $TargetName"
Description="Beginning the upgrade for $TargetName. Your computer will reboot
automatically and the entire process will take approximately 30 minutes."

"$JamfHelper" -windowType fs -title "$Title" -icon "$InstallIcon" -heading "$Heading" -description "$Description" &
HelperNotificationPID=$!

# Keep the computer alive
/usr/bin/caffeinate -dis &
CaffeinatePID=$!

# Drop some pre and post install items in place
FinishScriptPath='/usr/local/jamfps/finishOSInstall.sh'
CleanupDaemonPath='/Library/LaunchDaemons/com.jamfps.cleanupOSInstall.plist'

if [[ ! -d '/usr/local/jamfps' ]]; then
	mkdir -p /usr/local/jamfps
fi

cat << EOF > "$FinishScriptPath"
#!/bin/bash
## First Run Script to remove the installer.


## Wait until /var/db/.AppleUpgrade disappears
while [ -e /var/db/.AppleUpgrade ];
do
	echo "\$(date "+%a %h %d %H:%M:%S"): Waiting for /var/db/.AppleUpgrade to disappear." >> /usr/local/jamfps/firstbootupgrade.log
    sleep 60
done
    
## Wait until the upgrade process completes
INSTALLER_PROGRESS_PROCESS=\$(pgrep -l "Installer Progress")
until [ "\$INSTALLER_PROGRESS_PROCESS" = "" ];
do
	echo "\$(date "+%a %h %d %H:%M:%S"): Waiting for Installer Progress to complete." >> /usr/local/jamfps/firstbootupgrade.log
    sleep 60
    INSTALLER_PROGRESS_PROCESS=\$(pgrep -l "Installer Progress")
done
## If user was elevated, remove
if [ -f $AdminFile ]; then
	if [[ \$(dscacheutil -q group -a name admin | grep $Username) ]]; then
		dseditgroup -o edit -d $Username admin
	fi
	rm -f "$AdminFile"
fi
## Clean up files
/bin/rm -fr "$Installer"
## Update Device Inventory
/usr/local/jamf/bin/jamf recon
## Remove LaunchDaemon
/bin/rm -f "$CleanupDaemonPath"
## Remove Script
/bin/rm -fr /usr/local/jamfps
exit 0
EOF

chown root:admin "$FinishScriptPath"
chmod 755 "$FinishScriptPath"

cat << EOF > "$CleanupDaemonPath"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.jamfps.cleanupOSInstall</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>$FinishScriptPath</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

chown root:wheel "$CleanupDaemonPath"
chmod 644 "$CleanupDaemonPath"

# Define the installer variables
InstallerLog="/private/tmp/startosinstall.log"


if [[ "$Type" == "Silicon" ]]; then
	InstallerParameters+=(
		"--agreetolicense"
		"--forcequitapps"
		"--user $Username"
		"--stdinpass"
		"--pidtosignal $HelperNotificationPID"
	)
elif [[ "$Type" == "Intel" ]]; then
	InstallerParameters+=(
		"--agreetolicense"
		"--nointeraction"
		"--forcequitapps"
		"--pidtosignal $HelperNotificationPID"
	)
fi

if [[ $EraseOrUpgrade == 1 ]]; then
	InstallerParameters+=("--eraseinstall")
	echo "Installer Start: INFO - Installer set to erase and install."
fi

# Before we get going, make sure there isn't already a log
if [ -f $InstallerLog ]; then
	rm -f $InstallerLog
fi

# Pull the lever, Kronk!
StartInstaller=$(echo \"$Installer/Contents/Resources/startosinstall\" ${InstallerParameters[@]})

if [[ "$Type" == "Silicon" ]]; then
	PushString=$(Interpret_Input 2 "$UserOptIn")
	nohup /usr/bin/expect -c "
set timeout -1
spawn $StartInstaller
sleep 2
send \"$PushString\r\"
expect \"Preparing\"
expect eof
" &> $InstallerLog &
	InstallerPID=$!
elif [[ "$Type" == "Intel" ]]; then
	eval "$StartInstaller" &> $InstallerLog &
	InstallerPID=$!
fi

# Wait for file to appear
echo "Installer Start: INFO - Installer was started with process ID: $InstallerPID"
echo "Installer Start: INFO - Waiting for log file."
while [ ! -f $InstallerLog ]; do
	sleep 0.1
done

# Wait for there to actually be output
echo "Installer Start: INFO - Waiting for log output."
while [[ $(cat $InstallerLog) == "" ]]; do
	sleep 0.1
done

# Check to make sure it didn't crap out
for ((i=1; i<4; i++)); do
	if [[ -z $(ps -p $InstallerPID) ]]; then
		Issue=$(cat $InstallerLog)
		echo "Installer Start: ERROR - Something went wrong with the upgrade."
		echo "$Issue"
		kill -9 $HelperNotificationPID
		Message="Something went wrong with the upgrade process. Please contact an administrator for support."
		/usr/bin/osascript -e 'display dialog "'"$Message"'" with title "Unable to Upgrade" buttons {"OK"} default button 1' &> /dev/null
		exit 1
	fi
	Check=$(cat $InstallerLog | grep "Preparing")
	if [[ -n $Check ]]; then
		echo "Installer Start: OK - Upgrade has successfully started."
		break
	fi
	sleep 5
done

exit 0
