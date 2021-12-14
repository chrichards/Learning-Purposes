#!/bin/bash

# To enable auto updating for an app, the appname must be specified
# as an argument to the script.
# Cyberduck
# Google Chrome
# Mozilla Firefox
# Microsoft Edge
# Microsoft Office
# PowerShell
# Slack
# zoom

# Define IFS
IFS=$'\n'

# Create an array of the script arguments
# If using Jamf, start on $4
if [[ "$1" =~ "/" ]]; then
	for (( i=1; i<4; i++ )); do
		shift 1
	done
fi

for item in $@; do
	if [[ "$item" =~ "Office" ]]; then
		CheckOffice="true"
	else
		Apps+=("$item")
	fi
done

# Functions
CheckAppExist () {
	Check=$(/usr/bin/find /Applications -name "*$1*" -maxdepth 2)
	
	if [[ -n "$Check" ]]; then
		/bin/echo "$Check"
	else
		/bin/echo "Not Installed"
	fi
}
	
CheckAppVersion () {
	Version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$1/Contents/Info.plist")
	
	if [[ -n "$Version" ]]; then
		/bin/echo "$Version"
	else
		/bin/echo "Unknown"
	fi
}

CheckLatestVersion () {
	if [[ "$1" == "$2" ]]; then
		/bin/echo "True"
	else
		/bin/echo "False"
	fi
}

DownloadApp () {
	Extension="${2##*.}"
	Package="/private/tmp/$1.$extension"
	
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
		rm -rf "$slackDmgPath"
		/usr/sbin/chown -R root:admin "/Applications/$Name.app"
	elif [[ "$Extension" =~ "zip" ]]; then
		/usr/bin/unzip "$Package"
		mv "/tmp/$Name.app" "/Applications"
		/usr/sbin/chown -R root:admin "/Applications/$Name.app"
	fi
	
	/bin/echo "$Name was updated"
}

# Check to see if the apps are installed

for App in ${Apps[@]}; do
	AppPath=$(CheckAppExist "$App")
	if [[ "$AppPath" != "Not Installed" ]]; then
		if [[ "$App" =~ " " ]]; then
			App=$(/bin/echo "$App" | /usr/bin/cut -d" " -f2)
		fi
		declare "array_$App=Path=$AppPath"
		Arrays+=("array_$App")
	fi
done
	
# Chrome
if [ -n "$array_Chrome" ]; then
	url="https://chromereleases.googleblog.com/search/label/Desktop%20Update"
	page=$(curl -s "$url")
	line=$(echo "$page" | awk '{gsub(">","\n",$0); print}' | grep "\d\.[4]" | grep -i "stable channel" | head -1)
	version=$(echo "$line" | sed -E 's/[^0-9]*(([0-9]+\.){0,4}[0-9][^.]).*/\1/')
	download="https://dl.google.com/chrome/mac/stable/accept_tos%3Dhttps%253A%252F%252Fwww.google.com%252Fintl%252Fen_ph%252Fchrome%252Fterms%252F%26_and_accept_tos%3Dhttps%253A%252F%252Fpolicies.google.com%252Fterms/googlechrome.pkg"

	array_Chrome+=("LatestVersion=$version")
	array_Chrome+=("Download=$download")
fi

# Cyberduck
if [ -n "$array_Cyberduck" ]; then
	url="https://cyberduck.io/download/"
	page=$(/usr/bin/curl -s "$url")
	table=$(/bin/echo "$page" | /usr/bin/awk '{gsub(">","\n",$0);print}' | /usr/bin/grep zip -A 10)
	version=$(/bin/echo "$table" | /usr/bin/grep -i version | /usr/bin/sed -E 's/[^0-9]*(([0-9]\.){0,4}[0-9]).*/\1/')
	download=$(/bin/echo "$table" | /usr/bin/grep -i download | /usr/bin/sed -E 's/.*(http.*\.zip) .*/\1/')
	
	array_Cyberduck+=("LatestVersion=$version")
	array_Cyberduck+=("Download=$download")
fi

# Firefox
if [ -n "$array_Firefox" ]; then
	url="https://www.mozilla.org/en-US/firefox/enterprise/#download"
	page=$(/usr/bin/curl -s $url)
	version=$(/bin/echo "$page" | /usr/bin/grep "data-latest-firefox" | /usr/bin/sed -r 's/.*data-latest-firefox="([^"]+).*/\1/')
	base="https://ftp.mozilla.org"
	url="$base/pub/firefox/releases/$version/mac/en-US/"
	page=$(/usr/bin/curl -s $url)
	part=$(/bin/echo "$page" | /usr/bin/grep "pkg" | /usr/bin/sed -r 's/.*href="([^"]+).*/\1/')
	download="$base$part"
	
	array_Firefox+=("LatestVersion=$version")
	array_Firefox+=("Download=$download")
fi

# Microsoft Edge
if [ -n "$array_Edge" ]; then
	url="https://www.microsoft.com/en-us/edge/business/download"
	page=$(/usr/bin/curl -s $url)
	version=$(/bin/echo "$page" | /usr/bin/grep "build-version" | /usr/bin/sed -E 's/[^0-9]*(([0-9]+\.){0,4}[0-9][^.]).*/\1/' | /usr/bin/head -1)
	download=$(/bin/echo "$page" | /usr/bin/grep "commercial-json-data" | /usr/bin/awk '{gsub(";","\n",$0); print}' | /usr/bin/grep -e "/MacAutoupdate/MicrosoftEdge-" | /usr/bin/head -1 | /usr/bin/sed 's/&quot//')

	array_Edge+=("LatestVersion=$version")
	array_Edge+=("Download=$download")
fi

# Microsoft Office
# Let the Microsoft Updater handle things
if [ -n "$CheckOffice" ]; then
	OfficeApps=$(/usr/bin/find /Applications -iname "*Microsoft*" ! -iname "*Edge*" -depth 1)
	if [ -n "$OfficeApps" ]; then
		/bin/echo "Office apps installed"
		msupdate=$(/usr/bin/find "/Library/Application Support" -name "*msupdate*" 2> /dev/null)
		if [ -n $msupdate ]; then
			/bin/echo "Updater already installed; will handle updates"
			/bin/echo "#############################"
		else
			url="https://docs.microsoft.com/en-us/officeupdates/release-history-microsoft-autoupdate"
			page=$(/usr/bin/curl -s $url)
			download=$(/bin/echo "$page" | /usr/bin/grep -i "macautoupdate" | /usr/bin/sed -E 's/.*href="([^"]+).*/\1/' | /usr/bin/head -1)
			
			declare "array_MUA=Path=NULL"
			Arrays+=("array_MUA")
			
			array_MUA+=("LatestVersion=NULL")
			array_MUA+=("Download=$download")
		fi
	fi
fi

# PowerShell
if [ -n "$array_PowerShell" ]; then
	url="https://github.com/PowerShell/PowerShell"
	page=$(/usr/bin/curl -s "$url")
	types=$(/bin/echo "$page" | /usr/bin/grep -i .pkg | /usr/bin/grep -Ev "lts|rc")
	one=$(/bin/echo "$types" | /usr/bin/head -1)
	two=$(/bin/echo "$types" | /usr/bin/tail -1)
	check=$(/usr/bin/arch)
	
	if [[ "$two" =~ "$check" ]]; then
		# it's arm
		use=$two
	else
		use=$one
	fi
	
	download=$(/bin/echo "$use" | /usr/bin/sed -E 's/.*href="([^"]+).*/\1/')
	version=$(/bin/echo "$download" | /usr/bin/sed -E 's/[^0-9]*(([0-9]+\.){0,4}[0-9]).*/\1/')
	
	array_PowerShell+=("LatestVersion=$version")
	array_PowerShell+=("Download=$download")
fi
	
# Slack
if [ -n "$array_Slack" ]; then
	url='https://downloads.slack-edge.com/mac_releases/releases.json'
	page=$(/usr/bin/curl -s "$url")
	parse=$(/bin/echo "$page" | /usr/bin/awk '{gsub(",","\n",$0);print}' | /usr/bin/tail -1 | /usr/bin/sed 's/,/\n/g')
	download=$(/bin/echo "$page" | /usr/bin/grep "url" | /usr/bin/cut -d: -f2 -f3 | /usr/bin/sed 's/"//g')
	version=$(/bin/echo "$page" | /usr/bin/grep "version" | /usr/bin/cut -d: -f2 | /usr/bin/sed 's/"//g')
	
	array_Slack+=("LatestVersion=$version")
	array_Slack+=("Download=$download")
fi

# Zoom
if [ -n "$array_zoom" ]; then
	url="https://zoom.us/client/latest/ZoomInstallerIT.pkg"
	page=$(/usr/bin/curl -sL -w %{url_effective} "$url" -o /dev/null)
	version=$(/bin/echo "$page" | /usr/bin/tr "/" "\n" | /usr/bin/grep -w "[0-9]")
	download=$url
	
	array_zoom+=("LatestVersion=$version")
	array_zoom+=("Download=$download")
fi

if [ -z "$Arrays" ]; then
	exit 0
fi

# Process everything that's detected
for Array in ${Arrays[@]}; do
	# Pull apart each array for comparison data
	Augment=$Array[*]
	AppName=$(/bin/echo "$Array" | /usr/bin/cut -d"_" -f2)
	Path=$(/bin/echo "${!Augment}" | /usr/bin/grep "Path" | /usr/bin/cut -d= -f2)
	LatestVersion=$(/bin/echo "${!Augment}" | /usr/bin/grep "LatestVersion" | /usr/bin/cut -d= -f2)
	DownloadUrl=$(/bin/echo "${!Augment}" | /usr/bin/grep "Download" | /usr/bin/cut -d= -f2)
	
	# Check currently installed version
	InstalledVersion=$(CheckAppVersion "$Path")
	if [[ "$InstalledVersion" == "Unknown" ]]; then
		/bin/echo "Could not determine version for $AppName"
		/bin/echo "#############################"
		continue
	fi
	
	# Does it match with what's available?
	UpToDate=$(CheckLatestVersion "$LatestVersion" "$InstalledVersion")
	if [[ "$UpToDate" == True ]]; then
		/bin/echo "$AppName is already up-to-date"
		/bin/echo "#############################"
		continue
	else
		/bin/echo "$AppName requires an update"
	fi
	
	# Download the latest version
	/bin/echo "Beginning app download for $AppName"
	Filepath=$(DownloadApp "$AppName" "$DownloadUrl")
	
	# Install the app
	InstallApp "$Filepath" "$AppName"
	
	# Just for cleanliness of output
	echo "#############################"
done
