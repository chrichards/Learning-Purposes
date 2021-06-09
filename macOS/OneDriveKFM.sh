#!/bin/bash
# Variables
Username=$(who | awk '/console/{print $1}' | head -n 1)
Application="Applications/OneDrive.app/Contents/MacOS/OneDrive"

# Is OneDrive evening running?
OneDriveRunning=$(ps -u $Username | grep $Application | grep -v grep)

if [[ $OneDriveRunning ]]; then
	echo "OneDrive is running."
else
	echo "OneDrive is not running."
	exit 1
fi

# What's the name of the OneDrive folder and does it exist?
OneDriveName=$(ls /Users/$Username | grep OneDrive)

if [[ $OneDriveName ]]; then
	OneDriveFolder="/Users/$Username/$OneDriveName"
	echo "OneDrive exists for user."
else
	echo "OneDrive is not setup."
	exit 1
fi

# Function
Process_Files () {
	# $1 = Actual name of folder
	# $2 = Static name of folder, e.g. "Desktop"
	# $3 = Full path of folder
	
	if [ "$1" == "$2 -> $OneDriveFolder/$2" ]; then
		echo "$2 already being redirected. Skipping..."
	else
		# Folder inside OneDrive
		if [ ! -d "$OneDriveFolder/$2" ]; then
			echo "OneDrive $2 is not setup."
			
			# Move files to OneDrive
			echo "Moving $2 to OneDrive..."
			mv "$3" "$OneDriveFolder"
			
			# Create a symbolic link
			echo "Linking OneDrive $2 to $2."
			ln -s "$OneDriveFolder/$2" "$3"
			
			# Set permissions to new folder
			echo "Adjusting permissions and ownership to $2 link."
			chown -R $Username "$3"
			chmod -R 755 "$3"
			
			echo "Adjusting permissions and ownership to OneDrive $2 files..."
			chown -R $Username "$OneDriveFolder/$2"
			chmod -R 755 "$OneDriveFolder/$2"
		else
			local Archive="/Users/$Username/Archive$2"
			
			# Folder exists in OneDrive so true-up files
			echo "OneDrive $2 already exists."
			
			# Copying files to OneDrive
			echo "Copying $2 to OneDrive..."
			cp -R "$3" "$OneDriveFolder"
			
			# Making a backup, just in case
			echo "Making a local backup: Archive$2"
			mv "$3" "$Archive"
			chflags hidden "$Archive"
			chown -R $Username "$Archive"
			chmod -R 755 "$Archive"
			
			# Create a symbolic link
			echo "Linking OneDrive $2 to $2."
			ln -s "$OneDriveFolder/$2" "$3"
			
			# Set permissions to new $2 area
			echo "Adjusting permissions and ownership to $2 link."
			chown -R $Username "$3"
			chmod -R 755 "$3"
			
			echo "Adjusting permissions and ownership to OneDrive $2 files..."
			chown -R $Username "$OneDriveFolder/$2"
			chmod -R 755 "$OneDriveFolder/$2"
		fi
	fi
}

# Are folders already redirected? If not, do that!
Desktop=$(ls -n "/Users/$Username/" | grep "Desktop" | awk '{print $9,$10,$11,$12,$13,$14}')
DesktopFolder="/Users/$Username/Desktop"
Process_Files "$Desktop" "Desktop" "$DesktopFolder"
echo ----------------------------------------------------


Documents=$(ls -n "/Users/$UserName/" | grep "Documents" | awk '{print $9,$10,$11,$12,$13,$14}')
DocumentsFolder="/Users/$Username/Documents"
Process_Files "$Documents" "Documents" "$DocumentsFolder"
echo ----------------------------------------------------

Pictures=$(ls -n "/Users/$UserName/" | grep "Pictures" | awk '{print $9,$10,$11,$12,$13,$14}')
PicturesFolder="/Users/$Username/Pictures"
Process_Files "$Pictures" "Pictures" "$PicturesFolder"
echo ----------------------------------------------------

exit 0
