#!/bin/sh
# Version 6.01

##############################################
# VARIABLES
##############################################
Organization="stevecorp" # feel free to change this as you see fit
UpdateSkip=($4)

# Icons that will be used in messaging
StopIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"
WarnIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertNoteIcon.icns"
GearIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarAdvanced.icns"

# Where all scripts will be stored
Store="/Library/Application Support/$Organization"

# The first alert that lets the user know
# updates are going to be installed; asks when to install/reboot
LaunchAgent1Name="com.$Organization.alert"
LaunchAgent1Path="/Library/LaunchAgents/$LaunchAgent1Name.plist"
LaunchAgent1ScriptPath="$Store/alertUser.sh"

# Launch agent that is activated if updates
# did not install after reboot
LaunchAgent2Name="com.$Organization.remediation"
LaunchAgent2Path="/Library/LaunchAgents/$LaunchAgent2Name.plist"
LaunchAgent2ScriptPath="$Store/remediation.sh"

# Launch Agent that makes sure the user presses the update button
LaunchAgent3Name="com.$Organization.watcher"
LaunchAgent3Path="/Library/LaunchAgents/$LaunchAgent3Name.plist"
LaunchAgent3ScriptPath="$Store/watcher.sh"

# Verify updates were installed on reboot
LaunchDaemonName="com.$Organization.removealert"
LaunchDaemonPath="/Library/LaunchDaemons/$LaunchDaemonName.plist"
LaunchDaemonScriptPath="$Store/removeAlert.sh"

# Used in conjunction with LaunchAgent1
TimerScriptPath="$Store/timer.scpt"
ChoiceScriptPath="$Store/choice.scpt"

# Update settings
SoftwareUpdatePlist="/Library/Preferences/com.apple.SoftwareUpdate.plist"
PreferredConfigs=(
"AutomaticCheckEnabled"
"AutomaticDownload"
"ConfigDataInstall"
"CriticalUpdateInstall"
"AutomaticallyInstallMacOSUpdates"
)
UpdateLog=/tmp/update$(date +%F).log

# Finally, how long the timer should run for (in seconds)
TimerCount=600 # 10 minutes


##############################################
# FUNCTIONS
##############################################
<<comment
Write_Log() {
	timestamp=$(date "+%Y-%m-%d %H:%M:%S")
	log="/var/log/macOS-update.log"
	message=$1
	echo "$timestamp -- $message" >> $log
}
comment

Write_Log() {
	timestamp=$(date "+%Y-%m-%d %H:%M:%S")
	log="/var/log/macOS-update.log"
    CYAN="\033[1;36m" # TODO REVERT
    GREEN="\033[1;32m" # TODO REVERT
    ENDCOLOR="\033[0m" # TODO REVERT
	message=$1
    echo "$timestamp -- ${GREEN}${BASH_SOURCE[0]}${ENDCOLOR} -- ${CYAN}$message${ENDCOLOR}" # TODO REVERT
	echo "$timestamp -- ${BASH_SOURCE[0]} -- $message" >> $log
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


##############################################
# SCRIPTS
##############################################
IFS='' read -r -d '' TimerScript <<EOF
use framework "Foundation"
use scripting additions

on run
	set arguments to (current application's NSProcessInfo's processInfo's arguments) as list
	set GivenTime to quoted form of (item 2 of arguments)
	progress_timer(GivenTime, "Timer")
end run

on getTimeConversion(HMS_Time)
	set HMSlist to the words of HMS_Time
	set theHours to item 1 of HMSlist
	set theMinutes to item 2 of HMSlist
	set theSeconds to item 3 of HMSlist
	return round (theHours * (60 ^ 2) + theMinutes * 60 + theSeconds)
end getTimeConversion

on progress_timer(HMS_Time, timerLabel)
	set theTimeSec to getTimeConversion(HMS_Time)
	set progress total steps to theTimeSec
	set progress completed steps to theTimeSec
	set progress description to "Note: Stop button will only close this timer; it does not stop the process.\r" & ¬
		"Time remaining before install and restart:"
	set startTime to (current date)
	repeat with i from 0 to theTimeSec
		set HMS_ToGo to TimetoText(theTimeSec - i)
		set progress additional description to ¬
			HMS_ToGo & return
		set progress completed steps to theTimeSec - i
		set elapsedTime to (current date) - startTime
		set lagAdjust to elapsedTime - i
		delay 1 - lagAdjust
	end repeat
end progress_timer

on TimetoText(theTime)
	if (class of theTime) as text is "integer" then
		set TimeString to 1000000 + 10000 * (theTime mod days div hours)
		set TimeString to TimeString + 100 * (theTime mod hours div minutes)
		set TimeString to (TimeString + (theTime mod minutes)) as text
		tell TimeString to set theTime to (text -6 thru -5) & ":" & (text -4 thru -3) & ":" & (text -2 thru -1)
	end if
	return theTime
end TimetoText
EOF

IFS='' read -r -d '' ChoiceScript <<EOF
set pass to null
set user_choices to {¬
	"Install updates and restart now", ¬
	"Snooze for 1 hour", ¬
	"Snooze for 3 hours", ¬
	"Snooze for 8 hours"}
	
repeat until pass is true
	set user_prompt to choose from list user_choices with prompt ¬
		"You system needs to install important updates which will require a restart. Please select from the following options:" with title "Attention Required"
		
	if result is false then
		display alert "Attention Required" message "You cannot choose to cancel at this time. Please try again." as critical with OK
		set pass to false
	else
		set pass to true
	end if
end repeat
return user_prompt
EOF

IFS='' read -r -d '' LaunchDaemonScript <<EOF
#!/bin/bash

Write_Log() {
	timestamp=\$(date "+%Y-%m-%d %H:%M:%S")
	log="/var/log/macOS-update.log"
	message=\$1
	echo "\$timestamp -- \$message" >> \$log
}

Month_to_Number () {
	case \$1 in
		'Jan') Month=1 ;;
		'Feb') Month=2 ;;
		'Mar') Month=3 ;;
		'Apr') Month=4 ;;
		'May') Month=5 ;;
		'Jun') Month=6 ;;
		'Jul') Month=7 ;;
		'Aug') Month=8 ;;
		'Sep') Month=9 ;;
		'Oct') Month=10 ;;
		'Nov') Month=11 ;;
		'Dec') Month=12 ;;
		*) Month=0 ;;
	esac
	
	echo \$Month
}

Date_to_Number () {
	Month=\$(Month_to_Number \$(echo \$1 | awk '{print \$1}'))
	Day=\$(echo \$1 | awk '{print \$2}')
	Time=\$(echo \$1 | awk '{print \$3}' | sed 's/://g')
	
	if [[ \$(echo \$1 | awk -F: '{print NF-1}') == 1 ]]; then
		Time="\${Time}00"
	fi
	
	echo "\$Month\$Day\$Time"
}

UserID=#REPLACE#
LastReboot=\$(last reboot | head -1 | awk '{print \$4" "\$5" "\$6}')
CurrentTime=\$(date | awk '{print \$2" "\$3" "\$4}')
Write_Log "Last reboot time reporting as: \$LastReboot"

CompareA=\$((\$(Date_to_Number "\$LastReboot")+1000000)) # Add a day
CompareB=\$(Date_to_Number "\$CurrentTime")

if (( CompareA > CompareB )); then
	Write_Log "Machine was recently rebooted."
	Rebooted='true'
else
	Write_Log "No recent reboot according to calculations."
	Rebooted='false'
fi

if [[ "\$Rebooted" == true ]]; then
	CurrentDate=\$(date +%Y%m%d)
	LastUpdate=\$(softwareupdate --history | grep -oE "[0-9]{2}/[0-9]{2}/[0-9]{4}" | tail -1)
	LastUpdateFormatted=\$(date -j -f %m/%d/%Y -v+3d \$LastUpdate +%Y%m%d)
	Write_Log "Last update installation reporting as: \$LastUpdateFormatted"
	
	if (( LastUpdateFormatted <= CurrentDate )); then
		Write_Log "Machine rebooted but did not install updates; need to remediate"
		RemediationNeeded="true"
	fi
	
	Write_Log "System updated successfully."
	/bin/launchctl bootout gui/\$UserID "$LaunchAgent1Path"
	/bin/rm -f "$LaunchAgent1Path"
	/bin/rm -f "$LaunchDaemonPath"
	
elif [[ "\$Rebooted" == false ]]; then
	Write_Log "Machine has not rebooted but LaunchDaemon proc'd"
	exit 0
else
	exit 1
fi

if [[ "\$RemediationNeeded" != true ]]; then
	Write_Log "System updated successfully."
	
	/bin/rm -f "$LaunchAgent2Path"
	/bin/rm -f "$LaunchAgent3Path"
	/bin/rm -rf "$Store"
	exit 0
fi

Write_Log "System update was unsuccessful. Notifying the user..."

/usr/bin/defaults write "$LaunchAgent2Path" "StartInterval" -int 1800
/usr/bin/defaults write "$LaunchAgent2Path" "RunAtLoad" -bool true
/usr/bin/defaults write "$LaunchAgent3Path" "RunAtLoad" -bool true

/bin/chmod 644 "$LaunchAgent2Path"
/bin/chmod 644 "$LaunchAgent3Path"

/bin/launchctl bootstrap gui/\$UserID "$LaunchAgent2Path"
/bin/launchctl bootstrap gui/\$UserID "$LaunchAgent3Path"

EOF

IFS='' read -r -d '' LaunchAgent1Script <<EOF
#!/bin/bash

open -a "$Store/Restart Reminder.app" --args 00:10:00 &
for (( i=0; i<$TimerCount; i++ )); do
	if (( i == 300 )); then
		check=\$(ps ax | grep "Restart Reminder" | grep -v grep)
		if [ -z \$check ]; then
			open -a "$Store/Restart Reminder.app" --args 00:05:00 &
		fi
	elif (( i == 540 )); then
		check=\$(ps ax | grep "Restart Reminder" | grep -v grep)
		if [ -z \$check ]; then
			open -a "$Store/Restart Reminder.app" --args 00:01:00 &
		fi
	fi
	sleep 1
done

arch=\$(/usr/bin/arch)
if [[ "\$arch" =~ "arm" ]]; then
	Grab=\$(cat "#REPLACE#")
	Part1=\$(ioreg -l | grep IOPlatformSerialNumber | cut -d= -f2 | sed -e 's/[[:space:]"]//g')
	Part2=\$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; getline; print \$NF}' | sed -e 's/[:]//g' | tr '[a-z]' '[A-Z]')
	Combo="\$Part1\$Part2"
	Input=\$(echo "\$Grab" | openssl enc -k "\$(echo \$Combo)" -md md5 -aes256 -base64 -d)
	/usr/bin/expect -f - <<EOD
set timeout -1
set send_human {.1 .3 1 .05 2}
log_file -a $UpdateLog
spawn /usr/sbin/softwareupdate --install --all --no-scan
expect "Password:"
send -h "\$Input\r"
expect "Password:"
send -h "\$Input\r"
expect eof
EOD
elif [[ "\$arch" == "i386" ]]; then
	/usr/sbin/softwareupdate --install --all --no-scan --restart
else
	# No idea how to handle this so we'll just exit
	# Give a unique exit code so we know -why- things failed
	exit 126
fi

EOF

IFS='' read -r -d '' LaunchAgent2Script <<EOF
#!/bin/bash

Write_Log() {
	timestamp=\$(date "+%Y-%m-%d %H:%M:%S")
	log="/var/log/macOS-update.log"
	message=\$1
	echo "\$timestamp -- \$message" >> \$log
}

Write_Log "Sending nag notification to user."

notification="Your system has not applied required updates. If you choose NOT to update now, you will be reminded every 30 minutes."
title="System Updates Required"
icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarAdvanced.icns"
choice=\$(/usr/bin/osascript -e 'display dialog "'"\$notification"'" with title "'"\$title"'" with icon {"'"\$icon"'"} with text buttons {"Now","Later"}')

if [[ "\$choice" =~ "Now" ]]; then
	open -b com.apple.systempreferences /System/Library/PreferencePanes/SoftwareUpdate.prefPane
fi

EOF

IFS='' read -r -d '' LaunchAgent3Script <<EOF
#!/bin/bash

UserID=#REPLACE#
check=\$(date +%F)
while :
do
	if [[ \$(cat "/var/log/install.log" | grep \$check".*SUAppStoreUpdateController: authorize") ]]; then
		break
	fi
	sleep 1
done

/bin/launchctl bootout gui/\$UserID "$LaunchAgent2Path"
/bin/launchctl bootout gui/\$UserID "$LaunchAgent3Path"
/bin/rm -f "$LaunchAgent2Path"
/bin/rm -f "$LaunchAgent3Path"
/bin/rm -rf "$Store"

EOF


##############################################
# PLISTS
##############################################
IFS='' read -r -d '' LaunchDaemon <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
	<key>Label</key>
	<string>$LaunchDaemonName</string>
	<key>ProgramArguments</key>
	<array>
	<string>/bin/sh</string>
	<string>$LaunchDaemonScriptPath</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	</dict>
</plist>
EOF

IFS='' read -r -d '' LaunchAgent1 <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
	<key>Label</key>
	<string>$LaunchAgent1Name</string>
	<key>ProgramArguments</key>
	<array>
	<string>/bin/sh</string>
	<string>$LaunchAgent1ScriptPath</string>
	</array>
	<key>RunAtLoad</key>
	<false/>
	</dict>
</plist>
EOF

IFS='' read -r -d '' LaunchAgent2 <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
	<key>Label</key>
	<string>$LaunchAgent2Name</string>
	<key>ProgramArguments</key>
	<array>
	<string>/bin/sh</string>
	<string>$LaunchAgent2ScriptPath</string>
	</array>
	<key>RunAtLoad</key>
	<false/>
	</dict>
</plist>
EOF

IFS='' read -r -d '' LaunchAgent3 <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
	<key>Label</key>
	<string>$LaunchAgent3Name</string>
	<key>ProgramArguments</key>
	<array>
	<string>/bin/sh</string>
	<string>$LaunchAgent3ScriptPath</string>
	</array>
	<key>RunAtLoad</key>
	<false/>
	</dict>
</plist>
EOF


##############################################
# MAIN AREA
##############################################
IFS=$'\n'
Write_Log "Beginning update automation checks..."

# Check to make sure automatic updating is setup
for Config in "${PreferredConfigs[@]}"; do
	Check=$(/usr/libexec/PlistBuddy -c "Print :$Config" $SoftwareUpdatePlist 2>&1)
	
	if [[ $Check =~ "Does Not Exist" || $Check != 'true' ]]; then
		Write_Log "Remediating '$Config : $Check'"
		/usr/bin/defaults write "$SoftwareUpdatePlist" $Config -bool true
	fi
done

# Check for updates
Write_Log "Checking for updates..."

# The softwareupdate binary can be finicky so we're gonna check it a few times
for ((i=1; i<4; i++)); do
	Updates=$(/usr/sbin/softwareupdate --list --all 2>&1)
done

# Are there updates? No point downloading/running things if there aren't
if [[ $(echo "$Updates" | grep "No new software available.") ]]; then
	# pretty self explainatory
	Write_Log "No new updates available."
	exit 0
fi

# Make sure we're ONLY getting updates for this OS
# Somehow, it can treat upgrades as "updates"
License=$(find / -iname "OSXSoftwareLicense.rtf" -print -quit 2>/dev/null)
OSFriendlyName=$(cat "$License" | grep -i "macOS" | head -1 | awk -F 'macOS ' '{print $NF}' | sed 's/\\//g')

# Turn the information into something a little bit more manageable
AvailableUpdates=($(echo "$Updates" | grep -i "Label" -A1 | awk '{$1=$1};1' | sed -e N -e 's/\n/, /g' -e 's/\* //g' -e 's/: /=/g' -e 's/, /,/g'))
RequiredUpdates=()
UpdatesByName=()
UpdatesWithRestart=()
UpdatesWithNoRestart=()

# Iterate through the array and make some fresh arrays
# This allows the information to be better separated and digested later
# NOTE: Because array index positions are absolute when declared, we can just put the data in and extract it later via index number
# NOTE: 0=Label, 1=Title, 2=Version, 3=Action
for ((i=0; i<${#AvailableUpdates[@]}; i++)); do
	IFS=',' read -r -a array <<< "${AvailableUpdates[$i]}"
	for index in "${array[@]}"; do
		case $index in
			Label*) Label=$(echo "$index" | cut -d'=' -f2);;
			Title*) Title=$(echo "$index" | cut -d'=' -f2);;
			Versi*) Version=$(echo "$index" | cut -d'=' -f2);;
			Actio*) Action=$(echo "$index" | cut -d'=' -f2);;
		esac
	done
	
	temp=("$Label","$Title","$Version","$Action")
	IFS=',' read -r -a Update$i <<< "${temp[@]}"
	unset temp Label Title Version Action
done

# Go through the update arrays and sort them/decide if they should be installed
for ((i=0; i<${#AvailableUpdates[@]}; i++)); do
	# If the update doesn't match the current OS, we skip
	if [[ ${Update$i[1]} =~ "macOS" ]]; then
		if [[ ${Update$i[1]} =~ $OSFriendlyName ]]; then
			# Check if the update is being skipped
			# If the update is in the array, it won't be added
			if [[ "${Update$i[2]}" =~ "${UpdateSkip[*]}" ]]; then
				# Make sure to turn off auto-updates
				# We don't want this update installing!
				for Config in "${PreferredConfigs[@]}"; do
					Check=$(/usr/libexec/PlistBuddy -c "Print :$Config" $SoftwareUpdatePlist 2>&1)
					
					if [[ $Check =~ "Does Not Exist" || $Check != 'false' ]]; then
						Write_Log "Redacting '$Config : $Check'"
						/usr/bin/defaults write "$SoftwareUpdatePlist" $Config -bool false
					fi
				done
			else
				# Add it to the pile!
				RequiredUpdates+=("${Update$i[0]}")
				UpdatesByName+=("${Update$i[1]}")
			fi
			# Check if the update requires a restart
			if [[ "${Update$i[3]" =~ "restart" ]]; then
				UpdatesWithRestart+=("${Update$i[0]}")
			else
				UpdatesWithNoRestart+=("${Update$i[0]}")
			fi
		fi
	# For all other updates, there's MasterCard	
	else
		RequiredUpdates+=("${Update$i[0]}")
		UpdatesByName+=("${Update$i[1]}")
		# Check if the update requires a restart
		if [[ "${Update$i[3]" =~ "restart" ]]; then
			UpdatesWithRestart+=("${Update$i[0]}")
		else
			UpdatesWithNoRestart+=("${Update$i[0]}")
		fi
	fi
done

# Write status update to log
if [ ${#RequiredUpdates[@]} -eq 0 ]; then
	Write_Log "No new updates available."
	exit 0
else
	Write_Log "The following updates will be installed: ${UpdatesByName[@]}"
fi

# Professor Oak: Are you an Intel or a Silicon?
arch=$(/usr/bin/arch)
if [[ "$arch" =~ "arm" ]]; then
	Write_Log "CPU Architecture: Silicon"
	Type="Silicon"
elif [[ "$arch" == "i386" ]]; then
	Write_Log "CPU Architecture: Intel"
	Type="Intel"
else
	# No idea how to handle this so we'll just exit
	Write_Log "CPU Architecture: Unknown"
	Write_Log "Unable to continue."
	# Give a unique exit code so we know -why- things failed
	exit 126
fi

# Define some user-based variables
Username=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ {print $3}')
if [[ ! -z "${Username// }" ]]; then
	Identifier=$(/usr/bin/dscl . -list /Users UniqueID | grep "$Username" | awk '{print $2}')
	Write_Log "$Username is logged in with ID: $Identifier"
fi
UserOptIn="/etc/security/$Identifier"
UserOptOut="/Users/$Username/OptOut"

# Is there a user logged in?
# If Intel and no one's logged in, run the updates
if [ -z $Username ] && [[ "$Type" == "Intel" ]]; then
	Write_Log "No users logged in. Running updates."
	for Update in "${RequiredUpdates[@]}"; do
		/usr/sbin/softwareupdate --download "$Update"
	done
	for Update in "${RequiredUpdates[@]}"; do
		/usr/sbin/softwareupdate --install "$Update" --restart &
	done
	exit 0
elif [ -z $Username ] && [[ "$Type" == "Silicon" ]]; then
	# Can only run updates if there's an OptIn file
	FilePresent=$(/usr/bin/find -E /etc/security -regex '.*[0-9]' | head -1)
	if [ -n "$FilePresent" ]; then
		Write_Log "No users logged in and opt-in file present. Checking password..."
		Identifier=$(echo "$FilePresent" | sed -e 's/\/etc\/security//g')
		Username=$(dscl . -list /Users UniqueID | grep $Identifier | awk '{print $1}')
		Input=$(Interpret_Input 2 "$UserOptIn")
		PassCheck=$(dscl . authonly "$Username" "$Input" &> /dev/null; echo $?)

		if [ "$PassCheck" -eq 0 ]; then
			Write_Log "Saved password works. Running updates."
			for Update in "${RequiredUpdates[@]}"; do
				launchctl asuser $Identifier sudo -u $Username /usr/bin/expect -f - <<EOD
set timeout -1
log_file -a $UpdateLog
spawn /usr/sbin/softwareupdate --download "$Update"
expect "Password:"
send "$Input\r"
expect eof
EOD
			done
			for Update in "${RequiredUpdates[@]}"; do
				launchctl asuser $Identifier sudo -u $Username /usr/bin/expect -f - <<EOD
set timeout -1
log_file -a $UpdateLog
spawn /usr/sbin/softwareupdate --install "$Update"
expect "Password:"
send "$Input\r"
expect "Password:"
send "$Input\r"
expect eof
EOD
			done
			exit 0
		else
			Write_Log "Saved password needs to be updated. Cannot do anything at this time."
			exit 0
		fi
	else
		Write_Log "No users logged in but no opt-in file available. Cannot do anything."
		exit 0
	fi
fi

# Intel Only: Do the thing
if [[ "$Type" == "Intel" ]]; then
	AutoUpdate="True"
fi

# Silicon Only: Check to see if user choice was ever offered
if [[ "$Type" == "Silicon" ]]; then
	# Before we can do anything, the user has to be identified as a token holder
	# If they don't have a token, they can't perform basically anything
	if [[ $(sysadminctl -secureTokenStatus $Username 2>&1) =~ "ENABLED" ]]; then
		Write_Log "User has a SecureToken."
	else
		Write_Log "User does not have a SecureToken."
		Write_Log "Cannot continue with update."
		Notification="You do not have a SecureToken assigned to your account. Please contact your administrator to help with remediation."
		Title="macOS Update Error"
		Choice=$(/usr/bin/osascript -e 'display dialog "'"$Notification"'" with title "'"$Title"'" with icon {"'"$StopIcon"'"} buttons {"OK"} default button 1')
		exit 1
	fi

	# Now we need to check for Volume Ownership
	DiskInfo=$(diskutil apfs listusers /)
	UserGUID=$(dscl . list /Users GeneratedUID | grep $Username | awk '{print $2}')
	VolumeOwner=$(echo "$DiskInfo" | grep $UserGUID -A 2)

	if [[ "$VolumeOwner" =~ "Yes" ]]; then
		# User is good to go
		Write_Log "User is a volume owner."
	else
		Write_Log "User is not a volume owner."
		Write_Log "Cannot continue with update."
		Notification="You are not a volume owner for your system. Please contact your administrator to help with remediation."
		Title="macOS Update Error"
		Choice=$(/usr/bin/osascript -e 'display dialog "'"$Notification"'" with title "'"$Title"'" with icon {"'"$StopIcon"'"} buttons {"OK"} default button 1')
		exit 1
	fi
	
	if [ -f "$UserOptOut" ]; then
		Write_Log "User has opted out of automatic updates at some point."
		# User opt-out always takes precedence
		# User has chosen to NOT allow automatic updates
		if [ -f "$UserOptIn" ]; then
			rm -f "$UserOptIn"
		fi
		AutoUpdate="False"
	elif [ -f "$UserOptIn" ]; then
		Write_Log "User is accepting automatic updates."
		# User has chosen to allow automatic updates at some point
		AutoUpdate="True"
		CheckValidity="True"
	else
		Write_Log "Presenting the user with automatic update choices."
		# User has not received prompt; throw one out there
		Notification="macOS Updates require your password each time they are available to install. Automatic updates can be configured to handle this task for you. Would you like to enroll now?\r\rNote: When you update your password, you will be asked again."
		Title="System Updates Required"
		
		Choice=$(/usr/bin/osascript -e 'display dialog "'"$Notification"'" with title "'"$Title"'" with icon {"'"$GearIcon"'"} with text buttons {"Yes","No"} default button "Yes"')
		Write_Log "User has chosen: $Choice"
		
		if [[ "$Choice" =~ "No" ]]; then
			# User does not want to have automatic updates
			echo "" > "$UserOptOut"
			/bin/chmod 777 "$UserOptOut"
			/usr/sbin/chown 
			AutoUpdate="False"
			Notification="You have chosen to not allow your organization to update your system for you. You will be reminded and responsible for all updates when they are available. If you would like to opt-in at any point, delete the file $UserOptOut to be prompted the next time this process runs."
			/usr/bin/osascript -e 'display dialog "'"$Notification"'" with title "'"$Title"'" with icon {"'"$GearIcon"'"} with text buttons {"OK"}'
		elif [[ "$Choice" =~ "Yes" ]]; then
			# User has opted in! Yay!
			AutoUpdate="True"
		fi
	fi
	
	if [[ "$AutoUpdate" == "True" ]]; then
		if [[ "$CheckValidity" == "True" ]]; then
			Write_Log "Checking stored password..."
			Check=$(Interpret_Input 2 "$UserOptIn")
		else
			Write_Log "Retrieving the user's password."
			Check=$(osascript -e 'display dialog "Please enter your password:" with hidden answer default answer ""' -e 'text returned of result' 2>/dev/null)
		fi
					
		Count=1
		while [[ "$Authenticated" != "True" ]]; do
			PassCheck=$(dscl . authonly "$Username" "$Check" &> /dev/null; echo $?)

			if [ "$PassCheck" -eq 0 ]; then
				Write_Log "Password is good and can be used."
				# User has input the correct password
				Authenticated="True"
				(Interpret_Input 1 "$Check") > "$UserOptIn"
			elif [[ "$Count" > 3 ]]; then
				Write_Log "User failed to input their password properly 3 times"
				Notification="You have exceeded the maximum number of password attempts. You will not be enrolled into automatic updates at this time.\r\rYou will be reminded and responsible for all updates when they are available. If you would like to opt-in at any point, delete the file $UserOptOut to be prompted the next time this process runs."
				/usr/bin/osascript -e 'display dialog "'"$Notification"'" with title "'"$Title"'" with icon {"'"$WarnIcon"'"} with text buttons {"OK"}'
				break
			else
				Write_Log "Asking user to re-enter their password..."
				Check=$(/usr/bin/osascript -e 'display dialog "The application password on-hand is either stale or incorrect. Please enter your current password:" with hidden answer default answer ""' -e 'text returned of result' 2>/dev/null)
				Authenticated="False"
				((Count++))
			fi
		done
	fi
fi
		
# Make sure the scripts have somewhere to live
if [ ! -d "$Store" ]; then
	Write_Log "$Store does not exist; creating..."
	mkdir "$Store"
fi

# Put all of the files where they need to go
if [[ "$AutoUpdate" == "True" ]]; then
	Files=(
	"ChoiceScript"
	"TimerScript"
	"LaunchAgent1"
	"LaunchAgent2"
	"LaunchAgent3"
	"LaunchAgent1Script"
	"LaunchAgent2Script"
	"LaunchAgent3Script"
	"LaunchDaemon"
	"LaunchDaemonScript"
	)
elif [[ "$AutoUpdate" == "False" ]]; then
	Files=(
	"LaunchAgent2"
	"LaunchAgent3"
	"LaunchAgent2Script"
	"LaunchAgent3Script"
	"LaunchDaemon"
	"LaunchDaemonScript"
	)
fi

for File in "${Files[@]}"; do
	FileScript=${!File}
	FilePath="${File}Path"
	if [ ! -f "${!FilePath}" ]; then
		Write_Log "${!FilePath} does not exist; creating..."
		echo "$FileScript" > "${!FilePath}"
		/usr/sbin/chown root:wheel "${!FilePath}"
		/bin/chmod 755 "${!FilePath}"
	fi
done

# Set the users that have opted out up with nag notifications
if [[ "$AutoUpdate" == "False" ]]; then
	/usr/bin/defaults write "$LaunchAgent2Path" "StartInterval" -int 1800
	/usr/bin/defaults write "$LaunchAgent2Path" "RunAtLoad" -bool true
	/usr/bin/defaults write "$LaunchAgent3Path" "RunAtLoad" -bool true

	/bin/chmod 644 "$LaunchAgent2Path"
	/bin/chmod 644 "$LaunchAgent3Path"

	/bin/launchctl bootstrap gui/$Identifier "$LaunchAgent2Path"
	/bin/launchctl bootstrap gui/$Identifier "$LaunchAgent3Path"
	exit 0
fi 

# Compile the timer and choice applications
/usr/bin/osacompile -o "$Store/Restart Reminder.app" "$TimerScriptPath"
/usr/bin/osacompile -o "$Store/Restart Choice.app" "$ChoiceScriptPath"

# Download the updates!
# Need password for silicon
Title="macOS Updates"
Notification="Downloading system updates..."
/usr/bin/osascript -e 'display notification "'"$Notification"'" with title "'"$Title"'"'

if [[ "$Type" == "Intel" ]]; then
	for Update in "${RequiredUpdates[@]}"; do
		/usr/sbin/softwareupdate --download "$Update" &> $UpdateLog
	done
elif [[ "$Type" == "Silicon" ]]; then
	Input=$(Interpret_Input 2 "$UserOptIn")
	for Update in "${RequiredUpdates[@]}"; do
		launchctl asuser $Identifier sudo -u $Username /usr/bin/expect -f - <<EOD
set timeout -1
set send_human {.1 .3 1 .05 2}
log_file -a $UpdateLog
spawn /usr/sbin/softwareupdate --download "$Update"
expect "Password:"
send -h "$Input\r"
expect eof
EOD
	done
fi

# If there are updates that don't require a restart, get them out of the way first
if [[ "${#UpdatesWithNoRestart[@]}" -ne 0 ]]; then
	if [[ "$Type" == "Intel" ]]; then
		for Update in "${UpdatesWithNoRestart[@]}"; do
			/usr/sbin/softwareupdate --install "$Update" &> $UpdateLog
		done
	elif [[ "$Type" == "Silicon" ]]; then
		Input=$(Interpret_Input 2 "$UserOptIn")
		for Update in "${UpdatesWithNoRestart[@]}"; do
			launchctl asuser $Identifier sudo -u $Username /usr/bin/expect -f - <<EOD
set timeout -1
set send_human {.1 .3 1 .05 2}
log_file -a $UpdateLog
spawn /usr/sbin/softwareupdate --install "$Update"
expect "Password:"
send -h "$Input\r"
expect eof
EOD
		done
	fi
fi

# Here's where we have the user impact updates (because of a restart)
if [[ "${#UpdatesWithRestart[@]}" -ne 0 ]]; then
	# Need to inject user auth into the LaunchAgent for Silicon
	if [[ "$Type" == "Silicon" ]]; then
		/usr/bin/sed -i '' "s|#REPLACE#|$UserOptIn|g" "$LaunchAgent1ScriptPath"
		/usr/bin/sed -i '' "s|#USERID#|$Identifier|g" "$LaunchAgent1ScriptPath"
		/usr/bin/sed -i '' "s|#USERNAME#|$Username|g" "$LaunchAgent1ScriptPath"
		/usr/bin/sed -i '' "s|#REPLACE#|$Identifier|g" "$LaunchDaemonScriptPath" 
		/usr/bin/sed -i '' "s|#REPLACE#|$Identifier|g" "$LaunchAgent3ScriptPath"
	fi

	# Prompt user and adjust from there
	# Times will have -10 minutes to account for timer
	UserChoice=$(/usr/bin/osascript "$Store/Restart Choice.app")

	case "$UserChoice" in
		'Install updates and restart now')
			StartTime=0	;;
		'Snooze for 1 hour')
			StartTime=1 ;;
		'Snooze for 3 hours')
			StartTime=3 ;;
		'Snooze for 8 hours')
			StartTime=8 ;;
	esac

	Write_Log "User has chosen '$UserChoice'"
		
	if [ "$StartTime" == 0 ]; then
		if [[ "$Type" == "Intel" ]]; then
			for Update in "${UpdatesWithRestart[@]}"; do
				/usr/sbin/softwareupdate --install --restart "$Update"
			done
		elif [[ "$Type" == "Silicon" ]]; then
			Input=$(Interpret_Input 2 "$UserOptIn")
			for Update in "${UpdatesWithRestart[@]}"; do
				launchctl asuser $Identifier sudo -u $Username /usr/bin/expect -f - <<EOD
set timeout -1
set send_human {.1 .3 1 .05 2}
log_file -a $UpdateLog
spawn /usr/sbin/softwareupdate --install "$Update"
expect "Password:"
send -h "$Input\r"
expect "Password:"
send -h "$Input\r"
expect eof
EOD
			done
		fi
		exit 0
	else
		CurrentHour=$(date +%H)
		StartHour=$((CurrentHour+StartTime))
		CurrentMinute=$(date +%M)
		StartMinute=$((CurrentMinute-10))
		if (( StartHour >= 24 )); then
			StartHour=$((StartHour-24))
		fi
		if (( StartMinute < 0 )); then
			StartHour=$((StartHour-1))
				if (( StartHour < 0 )); then
					StartHour=23
				fi
			StartMinute=$((60+StartMinute))
		fi
		
		/usr/libexec/PlistBuddy -c "add :StartCalendarInterval dict" -c "add :StartCalendarInterval:Hour integer $StartHour" -c "add :StartCalendarInterval:Minute integer $StartMinute" "$LaunchAgent1Path"
		/bin/chmod 644 "$LaunchAgent1Path"
		/bin/launchctl bootstrap gui/$Identifier "$LaunchAgent1Path"
		exit 0
	fi
else
	Write_Log "Updates have been installed."
	/bin/rm -f "$LaunchDaemonPath"
	/bin/rm -f "$LaunchAgent1Path"
	/bin/rm -f "$LaunchAgent2Path"
	/bin/rm -f "$LaunchAgent3Path"
	if [ -d $Store ]; then
		/bin/rm -rf "$Store"
	fi
	exit 0
fi
