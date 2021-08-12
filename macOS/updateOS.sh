#!/bin/bash

##############################################
# VARIABLES
##############################################
if [ -n $4 ]; then
	Organization=$(echo "$4" | awk '{print tolower($0)}')
else
	Organization="stevecorp"
fi

# Where all scripts will be stored
Store="/Library/Application Support/$Organization"

# The first alert that lets the user know
# updates are going to be installed; asks when to install/reboot
LaunchAgentName1="com.$Organization.alert"
LaunchAgentPath1="/Library/LaunchAgents/$LaunchAgentName1.plist"
LaunchAgentScriptPath1="$Store/alertUser.sh"

# Launch agent that is activated if updates
# did not install after reboot
LaunchAgentName2="com.$Organization.remediation"
LaunchAgentPath2="/Library/LaunchAgents/$LaunchAgentName2.plist"
LaunchAgentScriptPath2="$Store/remediation.sh"

# Launch Agent that makes sure the user presses the update button
LaunchAgentName3="com.$Organization.watcher"
LaunchAgentPath3="/Library/LaunchAgents/$LaunchAgentName3.plist"
LaunchAgentScriptPath3="$Store/watcher.sh"

# Verify updates were installed on reboot
LaunchDaemonName="com.$Organization.removealert"
LaunchDaemonPath="/Library/LaunchDaemons/$LaunchDaemonName.plist"
LaunchDaemonScriptPath="$Store/removeAlert.sh"

# Used in conjunction with LaunchAgent1
PythonTimerScriptPath="$Store/timer.py"
PythonChoiceScriptPath="$Store/choice.py"

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


##############################################
# SCRIPTS AND PLISTS
##############################################
IFS='' read -r -d '' PythonTimerScript <<EOF
#!/usr/bin/python

import time
import tkinter as tk

def countdown(t):
	mins, secs = divmod(t, 60)
	timer = '{:02d}:{:02d}'.format(mins, secs)
	label1['text'] = timer
	
	if t > 0:
		parent.after(1000, countdown, t-1)
	else:
		parent.quit()
		
t = 600
parent = tk.Tk()
parent.geometry("250x100")
parent.title("Restart Required")

label1 = tk.Label(parent, font = "Impact 48 bold")
label2 = tk.Label(parent, text = "Your machine is about to restart.")
label2.pack()
label1.pack()

countdown(int(t))

parent.eval('tk::PlaceWindow . center')
parent.attributes("-topmost", True)
parent.resizable(False, False)
parent.overrideredirect(1)

parent.mainloop()
EOF

IFS='' read -r -d '' PythonChoiceScript <<EOF
#!/usr/bin/python

from tkinter import *

options = [
"Install updates and restart now",
"Snooze for 1 hour",
"Snooze for 3 hours",
"Snooze for 8 hours"
]

def select():
    parent.quit()
    
parent = Tk()
parent.geometry("400x100")
parent.title("macOS Updates")

choice = StringVar(parent)
choice.set(options[0])

labelText = "Your system needs to install important updates which will require a restart. Please select from the following options:"
label1 = Label(parent, text=labelText, font="Vedana 12", wraplength=390, justify=CENTER)
label1.pack()

menu = OptionMenu(parent, choice, *options)
menu.pack()

button = Button(parent, text="Select", command=select)
button.pack()

parent.eval('tk::PlaceWindow . center')
parent.attributes("-topmost", True)
parent.resizable(False, False)
parent.overrideredirect(1)

parent.mainloop()

print choice.get()
EOF

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

IFS='' read -r -d '' LaunchDaemonScript <<EOF
#!/bin/bash
Month_to_Number () {
	case $1 in
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
	
	echo $Month
}

Date_to_Number () {
	Month=$(Month_to_Number $(echo $1 | awk '{print $1}'))
	Day=$(echo $1 | awk '{print $2}')
	Time=$(echo $1 | awk '{print $3}' | sed 's/://g')
	
	if [[ $(echo $1 | awk -F: '{print NF-1}') == 1 ]]; then
		Time="${Time}00"
	fi
	
	echo "$Month$Day$Time"
}

LastReboot=$(last reboot | head -1 | grep -oE "[aA-zZ]{3} [0-9]{2} [0-9]{2}:[0-9]{2}")
CurrentTime=$(date | awk '{print $2" "$3" "$4}')

CompareA=$(($(Date_to_Number "$LastReboot")+1000000)) # Add a day
CompareB=$(Date_to_Number "$CurrentTime")

if (( CompareA > CompareB )); then
	Rebooted='true'
else
	Rebooted='false'
fi

if [[ "$Rebooted" == true ]]; then
	CurrentDate=$(date +%m/%d/%Y)
	LastUpdate=$(softwareupdate --history | grep -oE "[0-9]{2}/[0-9]{2}/[0-9]{4}" | tail -1)
	
	if [[ "$LastUpdate" != "$CurrentDate" ]]; then
		RemediationNeeded="true"
	fi
	
	/bin/launchctl unload "$LaunchAgentPath1"
	/bin/launchctl unload "$LaunchDaemonPath"
	rm -f "$LaunchAgentPath1"
	rm -f "$LaunchDaemonPath"
elif [[ "$Rebooted" == false ]]; then
	exit 0
else
	exit 1
fi

if [[ "$RemediationNeeded" != true ]]; then
	rm -f "$LaunchAgentPath2"
	rm -f "$LaunchAgentPath3"
	rm -rf "$Store"
	exit 0
fi

/usr/bin/defaults write "$LaunchAgentPath2" "StartInterval" 1800
/usr/bin/defaults write "$LaunchAgentPath3" "RunAtLoad" -bool true

/bin/chmod 644 "$LaunchAgentPath2"
/bin/chmod 644 "$LaunchAgentPath3"

/bin/launchctl load "$LaunchAgentPath2"
/bin/launchctl load "$LaunchAgentPath3"

EOF

IFS='' read -r -d '' LaunchAgent1 <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
    <key>Label</key>
    <string>$LaunchAgentName1</string>
    <key>ProgramArguments</key>
    <array>
    <string>/bin/sh</string>
    <string>$LaunchAgentScriptPath1</string>
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
    <string>$LaunchAgentName2</string>
    <key>ProgramArguments</key>
    <array>
    <string>/bin/sh</string>
    <string>$LaunchAgentScriptPath2</string>
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
    <string>$LaunchAgentName3</string>
    <key>ProgramArguments</key>
    <array>
    <string>/bin/sh</string>
    <string>$LaunchAgentScriptPath3</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    </dict>
</plist>
EOF

IFS='' read -r -d '' LaunchAgentScript1 <<EOF
#!/bin/bash

/usr/bin/python "$PythonTimerScriptPath" &
/bin/sleep 600
/usr/sbin/softwareupdate --install --all --restart &
exit 0
EOF

IFS='' read -r -d '' LaunchAgentScript2 <<EOF
#!/bin/bash

notification="Your system was unable to update on its own and requires your attention. If you choose not to update now, you will be reminded every 30 minutes."
title="System Updates Required"
icon="/System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns"
choice=$(/usr/bin/osascript -e 'display dialog "'"$notification"'" with title "'"$title"'" with icon {"'"$icon"'"} with text buttons {"Now","Later"}')

if [[ "$choice" =~ "Now" ]]; then
	open -b com.apple.systempreferences /System/Library/PreferencePanes/SoftwareUpdate.prefPane
fi

exit 0
EOF

IFS='' read -r -d '' LaunchAgentScript3 <<EOF
#!/bin/bash

check=$(date +%F)
while :
do
    if [[ $(cat "/var/log/install.log" | grep $check".*SUAppStoreUpdateController: authorize") ]]; then
        break
    fi
    sleep 1
done

/bin/launchctl unload "$LaunchAgentPath2"
/bin/launchctl unload "$LaunchAgentPath3"
rm -f "$LaunchAgentPath2"
rm -f "$LaunchAgentPath3"
rm -rf "$Store"

EOF


##############################################
# MAIN AREA
##############################################
# Make sure the scripts have somewhere to live
if [ ! -d "$Store" ]; then
	mkdir "$Store"
fi

if [ ! -f "$PythonChoiceScriptPath" ]; then
	echo "$PythonChoiceScript" > "$PythonChoiceScriptPath"
	/usr/sbin/chown root:wheel "$PythonChoiceScriptPath"
	/bin/chmod 644 "$PythonChoiceScriptPath"
fi

if [ ! -f "$PythonTimerScriptPath" ]; then
	echo "$PythonTimerScript" > "$PythonTimerScriptPath"
	/usr/sbin/chown root:wheel "$PythonTimerScriptPath"
	/bin/chmod 644 "$PythonTimerScriptPath"
fi

# Drop the LaunchAgents in
if [ ! -f "$LaunchAgentPath1" ]; then
	echo "$LaunchAgent1" > "$LaunchAgentPath1"
	/usr/sbin/chown root:wheel "$LaunchAgentPath1"
	/bin/chmod 644 "$LaunchAgentPath1"
fi

if [ ! -f "$LaunchAgentPath2" ]; then
	echo "$LaunchAgent2" > "$LaunchAgentPath2"
	/usr/sbin/chown root:wheel "$LaunchAgentPath2"
	/bin/chmod 644 "$LaunchAgentPath2"
fi

if [ ! -f "$LaunchAgentPath3" ]; then
	echo "$LaunchAgent3" > "$LaunchAgentPath3"
	/usr/sbin/chown root:wheel "$LaunchAgentPath3"
	/bin/chmod 644 "$LaunchAgentPath3"
fi

# Now add all the LaunchAgent Scripts to the mix
if [ ! -f "$LaunchAgentScriptPath1" ]; then
	echo "$LaunchAgentScript1" > "$LaunchAgentScriptPath1"
	/usr/sbin/chown root:wheel "$LaunchAgentScriptPath1"
	/bin/chmod 644 "$LaunchAgentScriptPath1"
fi

if [ ! -f "$LaunchAgentScriptPath2" ]; then
	echo "$LaunchAgentScript2" > "$LaunchAgentScriptPath2"
	/usr/sbin/chown root:wheel "$LaunchAgentScriptPath2"
	/bin/chmod 644 "$LaunchAgentScriptPath2"
fi

if [ ! -f "$LaunchAgentScriptPath3" ]; then
	echo "$LaunchAgentScript3" > "$LaunchAgentScriptPath3"
	/usr/sbin/chown root:wheel "$LaunchAgentScriptPath3"
	/bin/chmod 644 "$LaunchAgentScriptPath3"
fi

# Drop the update checking daemon in place
if [ ! -f "$LaunchDaemonPath" ]; then
	echo "$LaunchDaemon" > "$LaunchDaemonPath"
	/usr/sbin/chown root:wheel "$LaunchDaemonPath"
	/bin/chmod 644 "$LaunchDaemonPath"
fi

# Make sure the daemon has something to run
if [ ! -f "$LaunchDaemonScriptPath" ]; then
	echo "$LaunchDaemonScript" > "$LaunchDaemonScriptPath"
	/usr/sbin/chown root:wheel "$LaunchDaemonScriptPath"
	/bin/chmod 644 "$LaunchDaemonScriptPath"
fi

# Check to make sure automatic updating is setup
for Config in "${PreferredConfigs[@]}"; do
	Check=$(/usr/libexec/PlistBuddy -c "Print :$Config" $SoftwareUpdatePlist 2>&1)
	
	if [[ $Check =~ "Does Not Exist" || $Check != 'true' ]]; then
		echo "Remediating '$Config : $Check'"
		/usr/bin/defaults write "$SoftwareUpdatePlist" $Config -bool true
	fi
done

# Run the updater
/usr/sbin/softwareupdate softwareupdate --install --all &> $UpdateLog

# Check the output
if [[ $(cat $UpdateLog | grep "No updates are available.") ]]; then
	echo "System is up-to-date."
	rm -f "$LaunchDaemonPath"
	rm -f "$LaunchAgentPath1"
	rm -f "$LaunchAgentPath2"
	rm -f "$LaunchAgentPath3"
	rm -rf "$Store"
	exit 0
elif [[ $(cat $UpdateLog | grep "Please restart immediately.") || $(cat $UpdateLog | grep "Downloaded") ]]; then
	echo "System needs to update."
else
	echo "Unable to determine system state."
	exit 1
fi

# Is there a user logged in?
Username=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ {print $3}')
if [ -z $Username ]; then
	echo "No users logged in. Running updates."
	/usr/sbin/softwareupdate --install --all --restart &
	exit 0
fi

# Prompt user and adjust from there
# Times will have -10 minutes to account for timer
UserChoice=$(/usr/bin/python "$PythonChoiceScriptPath")

case "$UserChoice" in
	'Install updates and restart now')
		StartTime=0	;;
	'Snooze for 1 hour')
		StartTime=3000 ;;
	'Snooze for 3 hours')
		StartTime=10200 ;;
	'Snooze for 8 hours')
		StartTime=28200 ;;
esac

echo "User has chosen '$UserChoice'"
	
if [ "$StartTime" == 0 ]; then
	/usr/sbin/softwareupdate --install --all --restart &
	exit 0
else
	/usr/bin/defaults write "$LaunchAgentPath1" "StartInterval" -integer "$StartTime"
	/bin/chmod 644 "$LaunchAgentPath1"
	/bin/launchctl load "$LaunchAgentPath1"
	exit 0
fi
