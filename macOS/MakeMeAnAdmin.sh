#!/bin/sh

############ Get Logged in User
# Get the current user that's logged in
currentUser=$(who | awk '/console/{print $1}' | head -n 1)

if [[ $(echo $currentUser) == "" ]]; then
    echo "No user currently logged in (but somehow this script was run...)"
    exit 0
else
    echo "The current user is $currentUser"
fi

############ Notify the user
# Let the user know they're about to have admin rights
notification='You will now have administrative privileges for 30 minutes. \
Actions during this time will be monitored and reported. \
Please use these rights responsibly.'

osascript -e 'display dialog "'"$notification"'" with title "Make Me An Admin" buttons {"Ok"} default button 1'


############ Create 30 minute monitor daemon
echo "Creating the job daemon"

# plist path
plist="/Library/LaunchDaemons/removeAdmin.plist"

if [ ! -f "$plist" ]; then
    script='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
    <key>Label</key>
    <string>removeAdmin</string>
    <key>ProgramArguments</key>
    <array>
    <string>/bin/sh</string>
    <string>/Library/Application Support/JAMF/removeAdminRights.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>1800</integer>
    <key>RunAtLoad</key>
    <true/>
    </dict>
</plist>'
    echo "$script" >> "$plist"

    # Set ownership of the file
    chown root:wheel "$plist"
    chmod 644 "$plist"
fi

launchctl load "$plist"
sleep 10

############ Make a file for removing
removePath="/private/var/userToRemove/user"

if [ ! -d /private/var/userToRemove ]; then
    mkdir /private/var/userToRemove
fi

echo $currentUser >> $removePath


############ Give the user admin rights
dseditgroup -o edit -a $currentUser -t user admin

############ Create a launcher for the daemon
removeScript='/Library/Application Support/JAMF/removeAdminRights.sh'

if [ -f "$removeScript" ]; then
    rm "$removeScript"
fi

touch "$removeScript"

# Read the user name quick to pass to the output script
userToRemove=$(cat $removePath)

cat <<EOF>> "$removeScript"
#!/bin/sh
if [[ -f /private/var/userToRemove/user ]]; then
    echo "Removing $userToRemove's admin privileges"
    dseditgroup -o edit -d $userToRemove -t user admin
    rm -f $removePath
    launchctl unload $plist
    rm $plist
    log collect --last 30m --output /private/var/userToRemove/$userToRemove.logarchive
fi
EOF

exit 0
