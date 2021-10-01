#!/bin/bash

# To enable auto updating for an app, the app short name must be specified
# as an argument to the script. 
# Google Chrome = Chrome
# Mozilla Firefox = Firefox
# Microsoft Edge = Edge
# Microsoft Office = Word
# zoom.us = zoom (note that this is lowercase)


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
	if [[ "$item" =~ "[[:space:]]" ]]; then
		item=$(/bin/echo "$item" | cut -d" " -f2)
	fi
	Apps+=("$item")
done

# Functions
CheckAppExist () {
	check=$(/usr/bin/find /Applications -name "*$1*" -maxdepth 1)
	if [[ -n "$check" ]]; then
		/bin/echo "$check"
	else
		/bin/echo "Not Installed"
	fi
}
	
CheckAppVersion () {
	version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$1/Contents/Info.plist")
	if [[ -n "$version" ]]; then
		/bin/echo "$version"
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
	package="/private/tmp/$1.pkg"
	if [ -f "$package" ]; then
		/bin/echo "$1 was already downloaded"
	else
		/usr/bin/curl -JL "$2" -o "$package"
	fi
}

InstallApp () {
	package="/private/tmp/$1.pkg"
	if [ ! -f "$package" ]; then
		/bin/echo "$1 was not available to install"
	else
		/usr/sbin/installer -pkg "$package" -target /
		/bin/rm -f "$package"
	fi
}

# Check to see if the apps are installed

for App in ${Apps[@]}; do
	AppPath=$(CheckAppExist "$App")
	if [[ "$AppPath" != "Not Installed" ]]; then
		declare "array_$App=Path=$AppPath"
		Arrays+=("array_$App")
	fi
done
	
# Chrome
if [ -n "$array_Chrome" ]; then
	url="https://chromereleases.googleblog.com"
	page=$(curl -s "$url")
	line=$(echo "$page" | awk '{gsub(">","\n",$0); print}' | grep "\d\.[4]" | grep -i "stable channel" | head -1)
	version=$(echo "$line" | sed -E 's/[^0-9]*(([0-9]+\.){0,4}[0-9][^.]).*/\1/')
	download="https://dl.google.com/chrome/mac/stable/accept_tos%3Dhttps%253A%252F%252Fwww.google.com%252Fintl%252Fen_ph%252Fchrome%252Fterms%252F%26_and_accept_tos%3Dhttps%253A%252F%252Fpolicies.google.com%252Fterms/googlechrome.pkg"

	array_Chrome+=("LatestVersion=$version")
	array_Chrome+=("Download=$download")
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
if [ -n "$array_Word" ]; then
	# Honestly, this is just a pain in the butt
	# The autoupdater is way more efficient so just check that THAT's installed
	# and make it do its thing
	msupdate=$(/usr/bin/find "/Library/Application Support" -name "*msupdate*" 2> /dev/null)
	if [ -n $msupdate ]; then
		installed='true'
	else
		installed='false'
	fi
	
	url="https://docs.microsoft.com/en-us/officeupdates/update-history-office-for-mac"
	page=$(/usr/bin/curl -s $url)
	download=$(/bin/echo "$page" | /usr/bin/grep -i "office suite" | /usr/bin/sed -nE 's/.*(https[^"]*).*/\1/p' | /usr/bin/head -1)
	longversion=$(/bin/echo ${download##*/} | /usr/bin/sed -E 's/[^0-9]*(([0-9]+\.){0,4}[0-9]*[^.])_.*/\1/')
	buildnumber=$(/bin/echo "$longversion" | /usr/bin/cut -d"." -f3)
	LatestVersion=$(/bin/echo "$page" | /usr/bin/grep "$buildnumber" | /usr/bin/head -1 | /usr/bin/sed -E 's/[^0-9]*(([0-9]+\.){0,3}[0-9][^.]).*/\1/')
	Path=$(/bin/echo "${array_Word[*]}" | /usr/bin/grep "Path" | /usr/bin/cut -d= -f2)
	AppName="Office"
	
	# Check currently installed version
	InstalledVersion=$(CheckAppVersion "$Path")
	if [[ "$InstalledVersion" == "Unknown" ]]; then
		/bin/echo "Could not determine version for $AppName"
	else
		UpToDate=$(CheckLatestVersion "$LatestVersion" "$InstalledVersion")
		if [[ "$UpToDate" == True ]]; then
			/bin/echo "$AppName is already up-to-date"
		else
			/bin/echo "$AppName requires an update"
			update='true'
		fi
	fi
	
	if [ -n "$update" ]; then
		if [[ $installed == false ]]; then
			/bin/echo "Downloading MUA"
			url="https://docs.microsoft.com/en-us/officeupdates/release-history-microsoft-autoupdate"
			page=$(/usr/bin/curl -s $url)
			link=$(/bin/echo "$page" | /usr/bin/grep -i "macautoupdate" | /usr/bin/sed -E 's/.*href="([^"]+).*/\1/' | /usr/bin/head -1)
			DownloadApp "MUA" "$link"
			InstallApp "MUA"
			msupdate=$(/usr/bin/find "/Library/Application Support" -name "*msupdate*" 2> /dev/null)
		fi
		
		"$msupdate" --install --terminate 300 --message "Microsoft Office requires an update and will close any open applications after 5 minutes."
	fi
	
	unset "array_Word"
	Arrays=( "${Arrays[@]/array_Word}" )
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
for Array in "${Arrays[@]}"; do
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
		continue
	fi
	
	# Does it match with what's available?
	UpToDate=$(CheckLatestVersion "$LatestVersion" "$InstalledVersion")
	if [[ "$UpToDate" == True ]]; then
		/bin/echo "$AppName is already up-to-date"
		continue
	else
		/bin/echo "$AppName requires an update"
	fi
	
	# Download the latest version
	/bin/echo "Beginning app download for $AppName"
	DownloadApp "$AppName" "$DownloadUrl"
	
	# Install the app
	InstallApp "$AppName"
	
	# Just for cleanliness of output
	echo "#############################"
done
