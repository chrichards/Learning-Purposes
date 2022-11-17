#!/bin/sh

# Get machine architecture
arch=$(/usr/bin/arch)

# Functions
DownloadApp () {
	Extension="${2##*.}"
	Package="/private/tmp/$1.$Extension"
	
	if [ -f "$Package" ]; then
		/bin/echo "$1 was already downloaded"
	else
		/usr/bin/curl -sJL "$2" -o "$Package"
	fi
	
	echo $Package
}

InstallApp () {
	Package="$1"
	Name="$2"
	Extension="${Package##*.}"
	
	if [ ! -f "$Package" ]; then
		/bin/echo "$Name was not available to install"
		break
	fi
	
	if [[ "$Extension" =~ "pkg" ]]; then
		/usr/sbin/installer -pkg "$Package" -target /
		/bin/rm -f "$Package"
	elif [[ "$Extension" =~ "dmg" ]]; then
		MountPt="/Volumes/$Name"
		AppPath="$MountPt/$Name.app"
		/usr/bin/hdiutil attach $Package -nobrowse
		cp -rf $AppPath "/Applications"
		/usr/bin/hdiutil detach $MountPt
		rm -rf "$Package"
		/usr/sbin/chown -R root:admin "/Applications/$Name.app"
	elif [[ "$Extension" =~ "zip" ]]; then
		/usr/bin/unzip "$Package"
		mv "/tmp/$Name.app" "/Applications"
		/usr/sbin/chown -R root:admin "/Applications/$Name.app"
	fi
}

# Gather information for PowerShell download
url="https://github.com/PowerShell/PowerShell"
page=$(/usr/bin/curl -s "$url")
types=$(/bin/echo "$page" | /usr/bin/grep -i .pkg | /usr/bin/grep -Ev "lts|rc|preview")
one=$(/bin/echo "$types" | /usr/bin/grep -i x64)
two=$(/bin/echo "$types" | /usr/bin/grep -i arm64)

if [[ "$two" =~ "$arch" ]]; then
	# it's arm
	use=$two
else
	use=$one
fi

# Install PowerShell
download=$(/bin/echo "$use" | /usr/bin/sed -E 's/.*href="([^"]+).*/\1/')
Filepath=$(DownloadApp "PowerShell" "$download")
InstallApp "$Filepath" "PowerShell"
mv /Applications/PowerShell.app /Applications/Utilities/
