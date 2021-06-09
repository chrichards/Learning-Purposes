#!/bin/bash

# Variables
DownloadTrigger="$4"
EraseOrUpgrade=$5
IFS=$'\n'

# Is it an upgrade or a wipe/install?
# If it's not explicitly a wipe, it's implicitly an upgrade
if [[ $EraseOrUpgrade != 1 ]]; then
	$EraseOrUpgrade=0
else
	# Really let the user know they're about to wipe the machine
	Title="WARNING"
	Message="You are about to perform an erase/upgrade. All files, applications, and data will be wipe from your system. Are you sure you want to continue?"
	/usr/bin/osascript -e 'display alert "'"$Title"'" message "'"$Message"'" as critical buttons {"Quit","Continue"} default button "Continue" cancel button "Quit"' &> /dev/null
	if [[ $? != 0 ]]; then
		echo "User Choice: ERROR - Upgrade did not continue."
		exit 1
	fi
fi

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
	Table=($(echo $Page | awk '{gsub("> <",">\n<",$0); print}' | grep "<td>" | sed 's/<[^>]*>//g'))

	# Split the table into Titles and Versions
	for ((i=0; i<${#Table[@]}; i++)); do
		if [[ $(($i % 2)) == 0 ]]; then
			Titles+=(${Table[$i]})
		else
			Versions+=(${Table[$i]})
		fi
	done
	
	LatestTitle=${Titles[0]}
	LatestVersion=${Versions[0]}
	echo "Update Info: OK - Latest from Apple is $LatestTitle $LatestVersion"
else
	echo "Update Info: ERROR - Could not verify information from Apple."
	exit 1
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

# Is there an installer already present?
# NOTE: While rare, it's possible to have *more than one* installer
# For that reason, the search is tossed into an array
OSInstaller=()
while IFS=  read -r -d $'\0'; do
	OSInstaller+=("$REPLY")
done < <(find /Applications -name "Install macOS*" -maxdepth 1 -print0)

# Function to download and make latest OS available
DownloadOS() {
	if [[ -n "$DownloadTrigger" ]]; then
		echo "OS Download: OK - Downloading latest macOS installer."
		if [[ -n /tmp/trigger_policy.log ]]; then
			rm -f /tmp/trigger_policy.log
		fi
		/usr/local/jamf/bin/jamf policy -event "$DownloadTrigger" >> /tmp/trigger_policy.log
		# Line for reporting
		echo "-------------------------"
		if [[ $? = 0 ]]; then
			Check=$(cat /tmp/trigger_policy.log | grep "No policies were found")
			if [[ -n $Check ]]; then
				echo "OS Download: ERROR - DownloadTrigger was unable to complete properly."
				exit 1
			else
				echo "OS Download: OK - DownloadTrigger policy ran successfully."
			fi
		else
			echo "OS Download: ERROR - DownloadTrigger was unable to complete properly."
			exit 1
		fi
	elif [[ -n $(softwareupdate 2> >(grep 'fetch-full-installer')) ]]; then
		echo "OS Download: OK - Using softwareupdate to get latest macOS installer."
		softwareupdate --fetch-full-installer
		# Line for reporting
		echo "-------------------------"
		if [[ $? = 0 ]]; then
			echo "OS Download: OK - softwareupdate ran successfully."
		else
			echo "OS Download: ERROR - softwareupdate was unable to complete properly."
			exit 1
		fi
	else
		echo "OS Download: ERROR - Unable to obtain latest version of macOS."
		exit 1
	fi
	
	Installer="/Applications/Install $LatestTitle.app"
}

# There are no Install macOS apps in /Applications
if [[ -z "$OSInstaller" ]]; then
	DownloadOS
else
# There's at least one installer to review
	for Installer in $OSInstaller; do
		echo "Checking $Installer against $LatestTitle"
		if [[ "$Installer" == *"$LatestTitle"* ]]; then
			echo "Installer Status: OK - $LatestTitle is ready to be installed."
			break
		else
		    unset Installer
		fi
	done
	# If all of the installers are stale
	if [[ -z "$Installer" ]]; then
		echo "Installer Status: WARN - System does not have the latest macOS installer."
		# Line for reporting
		echo "-------------------------"
		DownloadOS
		if [ -d "/Applications/Install $LatestTitle.app" ]; then
			echo "Installer Status: OK - $LatestTitle is ready to be installed."
			Installer="/Applications/Install $LatestTitle.app"
		else
			echo "Installer Status: ERROR - Unable to get $LatestTitle."
			exit 1
		fi
	else
		echo "Installer Status: INFO - Making sure installer isn't obsolete."
		InstallerInfoPlist=$(find $Installer -name "*Info*.plist" -maxdepth 2)
		InstallerVersion=$(/usr/libexec/PlistBuddy -c 'Print :DTPlatformVersion' "$InstallerInfoPlist")
		if [[ "$InstallerVersion" != "$LatestVersion" ]]; then
			echo "Installer Status: WARN - Current installer with version $InstallerVersion needs to be replaced"
			rm -f $Installer
			# Line for reporting
			echo "-------------------------"
			DownloadOS
			if [ -d "/Applications/Install $LatestTitle.app" ]; then
				echo "Installer Status: OK - $LatestTitle is ready to be installed."
				Installer="/Applications/Install $LatestTitle.app"
			else
				echo "Installer Status: ERROR - Unable to get $LatestTitle."
				exit 1
			fi
		else
			echo "Installer Status: OK - $LatestTitle is ready to be installed."
		fi
	fi
fi

# Line for reporting
echo "-------------------------"

# The notifier
JamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

# Generic icons
WarnIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns"
StopIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"

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

if [[ -n $PowerNotificationPID ]]; then
	kill -9 $PowerNotificationPID
fi

# Line for reporting
echo "-------------------------"

# Kill processes that aren't supposed to be running
Processes=$(ps -ax)
Targets=("caffeinate" "startosinstall" "osinstallersetup")
for Target in "${Targets[@]}"; do
	Check=$(echo Processes | grep $Target)
	if [[ -n $Check ]]; then
		kill -9 $(echo $Check | awk '{print $1}')
	fi
done

# User notification variables
InstallIcon="$Installer/Contents/Resources/InstallAssistant.icns"
Title="$LatestTitle Upgrade"
Heading="Please wait while we prepare your computer for $LatestTitle"
Description="Beginning the upgrade for $LatestTitle. Your computer will reboot
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
## Clean up files
/bin/rm -fr "$OSInstaller"
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
InstallerLog="/var/log/startosinstall.log"
InstallerParameters+=(
"--agreetolicense"
"--nointeraction"
"--forcequitapps"
"--pidtosignal $HelperNotificationPID"
)

if [[ $EraseOrUpgrade == 1 ]]; then
	InstallerParameters+=("--eraseinstall")
	echo "Installer Start: INFO - Installer set to erase and install."
fi

# Before we get going, make sure there isn't already a log
if [ -f $InstallerLog ]; then
	rm -f $InstallerLog
fi

# Pull the lever, Kronk!
StartInstaller="\"$Installer/Contents/Resources/startosinstall\" ${InstallerParameters[*]}"
eval "$StartInstaller" &> $InstallerLog &
InstallerPID=$!

# Wait for file to appear
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
	if [[ -z $(ps -p $InstallerPID -o pid=) ]]; then
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
