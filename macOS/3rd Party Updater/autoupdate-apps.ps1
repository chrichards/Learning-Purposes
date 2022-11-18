#!/usr/local/bin/pwsh
# Variables
$ProgressPreference = 'SilentlyContinue'
$AppList = @(
	"Google Chrome",
	"Cyberduck",
	"Firefox",
	"Microsoft Edge",
	"Microsoft Office",
	"PowerShell",
	"Slack",
	"zoom"
)

$InstalledApps = New-Object Collections.ArrayList

# Functions
Function Get-AppExist () {
    Param ($AppName)

    $Check = (Get-ChildItem -Path /Applications -Recurse -Filter "*$AppName*" -Depth 1).FullName

    If ($Check) {
        Return $Check
    }
    Else {
        Return "Not Installed"
    }
}

Function Get-InstalledVersion () {
	Param ($AppPath,$SearchString)

	If (Test-Path -Path $AppPath) {
		$Version = /usr/libexec/PlistBuddy -c "Print $SearchString" "$AppPath/Contents/Info.plist"
    }
    Else {
        $Version = "Unknown"
    }

	Return $Version

}

Function Get-InstallPackage {
	Param ($AppName,$DownloadUrl)
	$Extension = $DownloadUrl.Substring($DownloadUrl.Length - 3)
	$Package   = "/private/tmp/$AppName.$Extension"
	
	If (Test-Path -Path "$Package") {
		Write-Host "$AppName was already downloaded"
	}
	Else {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $Package
	}
	
	Return $Package
}

Function Set-InstallPackage {
	Param ($Package,$AppName)
	$Extension = $Package.Substring($Package.Length - 3)
	
	If (-Not(Test-Path -Path "$Package")) {
		Write-Host "$AppName was not available to install"
		break
	}
	
	If ($Extension -match "pkg") {
		Start-Process /usr/sbin/installer -ArgumentList "-pkg $Package -target /" -Wait
		Remove-Item -Path "$Package" -Force
    }
	ElseIf ($Extension -match "dmg") {
		$MountPt = "/Volumes/$AppName"
		$AppPath = "$MountPt/$AppName.app"
		Start-Process /usr/bin/hdiutil -ArgumentList "attach $Package -nobrowse" -Wait
		Copy-Item -Path $AppPath -Destination "/Applications" -Recurse -Force
		Start-Process /usr/bin/hdiutil -ArgumentList "detach $MountPt" -Wait
		Remove-Item -Path "$Package" -Recurse -Force
		Start-Process /usr/sbin/chown -ArgumentList "-R root:admin `"/Applications/$Name.app`"" -Wait
	}
	ElseIf ($Extension -match "zip") {
		Start-Process /usr/bin/unzip -ArgumentList "`"$Package`"" -Wait
		Move-Item -Path "/tmp/$AppName.app" -Destination "/Applications"
		Start-Process /usr/sbin/chown -ArgumentList "-R root:admin `"/Applications/$AppName.app`"" -Wait
	}
}

# Pre-Main Area
# Check if Tls is setup
If ([System.Net.ServicePointManager]::SecurityProtocol -notmatch "Tls") {
    [System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

# Figure out which apps are installed on the machine before collecting information
ForEach ($App in $AppList) {

	If ($App -match "Office") {
		# If statement to see if literally ANY of these apps exist
		# Is there a better way of doing it? Probably! But here we are...
		If ((Test-Path -Path "/Applications/Company Portal.app") -or ((Test-Path -Path "/Applications/Microsoft*.app") -and !(Test-Path -Path "/Applications/Microsoft Edge.app"))) {
            Write-Output "Discovered: Office app(s)"
			$temp = [PsCustomObject]@{
				AppName      = "AutoUpdate"
				AppPath      = "/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app"
                Version      = ""
                Download     = ""
                SearchString = ""
            }
			$InstalledApps.Add($temp) | Out-Null
			Continue
		}
	}
	$AppPath = Get-AppExist -AppName $App
    If ($App -match "\s") {
        $App = ($App -Split "\s")[1]
    }
	If ($AppPath -ne "Not Installed") {
        Write-Output "Discovered: $App"
		$temp = [PsCustomObject]@{
			AppName      = $App
			AppPath      = $AppPath
            Version      = ""
            Download     = ""
            SearchString = ""
        }
		$InstalledApps.Add($temp) | Out-Null
	}
}

# For purposes of clean reporting
Write-Output "#############################"

##########################################
# APPS AREA!
# It's alphabetical!
##########################################
# Chrome
If ("Chrome" -in $InstalledApps.AppName) {
    $url = "https://chromereleases.googleblog.com/search/label/Desktop%20Update"
    $page = Invoke-WebRequest -Uri $url -UseBasicParsing
    $version = ($page.Content -Split ">" | Where-Object {$_ -match 'the stable channel has been updated'} | Select-Object -First 1) -Replace "\s|[a-zA-Z</]"
    $download = "https://dl.google.com/chrome/mac/stable/accept_tos%3Dhttps%253A%252F%252Fwww.google.com%252Fintl%252Fen_ph%252Fchrome%252Fterms%252F%26_and_accept_tos%3Dhttps%253A%252F%252Fpolicies.google.com%252Fterms/googlechrome.pkg"
    ($InstalledApps | Where-Object {$_.AppName -match "Chrome"}).Version = $version
    ($InstalledApps | Where-Object {$_.AppName -match "Chrome"}).Download = $download
    ($InstalledApps | Where-Object {$_.AppName -match "Chrome"}).SearchString = "CFBundleShortVersionString"
}

# Cyberduck
If ("Cyberduck" -in $InstalledApps.AppName) {
    $url = "https://cyberduck.io/download/"
    $page = Invoke-WebRequest -Uri $url -UseBasicParsing -SkipHttpErrorCheck -SkipCertificateCheck
    $download = ($page.Links | Where-Object {$_ -match "zip"}).href
    $version = ($download -Replace "[^0-9\.]").Trim(".")
    ($InstalledApps | Where-Object {$_.AppName -match "Cyberduck"}).Version = $version
    ($InstalledApps | Where-Object {$_.AppName -match "Cyberduck"}).Download = $download
    ($InstalledApps | Where-Object {$_.AppName -match "Cyberduck"}).SearchString = "CFBundleShortVersionString"
}

# Firefox
If ("Firefox" -in $InstalledApps.AppName) {
    $url = "https://www.mozilla.org/en-US/firefox/enterprise/#download"
    $page = Invoke-WebRequest -Uri $url -UseBasicParsing
    $filter = $page.Content -Split "\n" | Where-Object {$_ -match "data-latest-firefox"}
    $version = ($filter -Split "\s").Where{$_ -match "data-latest-firefox"} -Replace '[a-z-="]'
    $base = "https://ftp.mozilla.org"
    $url = "$base/pub/firefox/releases/$version/mac/en-US/"
    $page = Invoke-WebRequest -Uri $url -UseBasicParsing
    $part = $page.Links.href.Where{$_ -match 'pkg'}
    $download = "$base$part"
    ($InstalledApps | Where-Object {$_.AppName -match "Firefox"}).Version = $version
    ($InstalledApps | Where-Object {$_.AppName -match "Firefox"}).Download = $download
    ($InstalledApps | Where-Object {$_.AppName -match "Firefox"}).SearchString = "CFBundleShortVersionString"
}

# Microsoft Edge
If ("Edge" -in $InstalledApps.AppName) {
    $url = "https://www.microsoft.com/en-us/edge/business/download"
    $page = Invoke-WebRequest -Uri $url -UseBasicParsing
    $download = ($page.content -split "\r" -split "," | Where-Object {$_ -match "MacAutoupdate"}) -Replace '\\u002F','/' -Replace 'downloadUrl:' -Replace '"' | Select-Object -First 1
    $version = ($download | Select-String -pattern '([0-9]{1,}\.){4}').Matches.Value.Trim(".")
    ($InstalledApps | Where-Object {$_.AppName -match "Edge"}).Version = $version
    ($InstalledApps | Where-Object {$_.AppName -match "Edge"}).Download = $download
    ($InstalledApps | Where-Object {$_.AppName -match "Edge"}).SearchString = "CFBundleShortVersionString"
}

# Microsoft Office
If ("AutoUpdate" -in $InstalledApps.AppName) {
    $url = "https://learn.microsoft.com/en-us/officeupdates/release-history-microsoft-autoupdate"
    $page = Invoke-WebRequest -Uri $url -UseBasicParsing
    $download = ($page.Links.Where{$_ -match ".pkg"}).href
    $version = ($download | Select-String -pattern "((\d+\.){1,}[0-9]+)").Matches.Value
    ($InstalledApps | Where-Object {$_.AppName -match "AutoUpdate"}).Version = $version
    ($InstalledApps | Where-Object {$_.AppName -match "AutoUpdate"}).Download = $download
    ($InstalledApps | Where-Object {$_.AppName -match "AutoUpdate"}).SearchString = "CFBundleVersion"
}

# PowerShell
If ("PowerShell" -in $InstalledApps.AppName) {
    $url = "https://github.com/PowerShell/PowerShell"
    $page = Invoke-WebRequest -Uri $url -UseBasicParsing
    $types = ($page.Links.Where{$_ -match ".pkg" -and $_ -notmatch "lts|rc"}).href
    $check = /usr/bin/arch

    If ($types[1] -match $check) {
        $use = $types[1]
    }
    Else {
        $use = $types[0]
    }

    $download = $use
    $version = ($download | Select-String -Pattern "((\d+\.){1,}[0-9]+)").Matches.Value
    ($InstalledApps | Where-Object {$_.AppName -match "PowerShell"}).Version = $version
    ($InstalledApps | Where-Object {$_.AppName -match "PowerShell"}).Download = $download
    ($InstalledApps | Where-Object {$_.AppName -match "PowerShell"}).SearchString = "CFBundleShortVersionString"
}

# Slack
If ("Slack" -in $InstalledApps.AppName) {
    $url = "https://slack.com/ssb/download-osx-universal"
    $page = Invoke-WebRequest -Uri $url -MaximumRedirection 0 -SkipHttpErrorCheck -SkipCertificateCheck -ErrorAction SilentlyContinue
    $download = $url
    $version = ($page.Headers.Location | Select-String -pattern "((\d+\.){1,}[0-9]+)").Matches.Value
    ($InstalledApps | Where-Object {$_.AppName -match "Slack"}).Version = $version
    ($InstalledApps | Where-Object {$_.AppName -match "Slack"}).Download = $download
    ($InstalledApps | Where-Object {$_.AppName -match "Slack"}).SearchString = "CFBundleShortVersionString"
}

# Zoom
If ("zoom" -in $InstalledApps.AppName) {
    $url = "https://zoom.us/client/latest/ZoomInstallerIT.pkg"
    $page = Invoke-WebRequest -Uri $url -MaximumRedirection 0 -SkipHttpErrorCheck -SkipCertificateCheck -ErrorAction SilentlyContinue
    $download = $url
    $version = ($page.Headers.Location | Select-String -pattern "((\d+\.){1,}[0-9]+)").Matches.Value
    ($InstalledApps | Where-Object {$_.AppName -match "zoom"}).Version = $version
    ($InstalledApps | Where-Object {$_.AppName -match "zoom"}).Download = $download
    ($InstalledApps | Where-Object {$_.AppName -match "zoom"}).SearchString = "CFBundleShortVersionString"
}

# Process everything that's been detected
ForEach ($App in $InstalledApps) {
    $AppName = $App.AppName
    $AppPath = $App.AppPath
    $AppVersion = $App.Version
    $DownloadUrl = $App.Download
    $AppVersionString = $App.SearchString

    # Check to see which version is installed
    $InstalledVersion = Get-InstalledVersion -AppPath $AppPath -SearchString $AppVersionString
    Write-Output "$AppName version showing as $InstalledVersion"
    Write-Output "Latest app version from vendor is $AppVersion"
    If ($InstalledVersion -eq "Unknown") {
        Write-Output "Could not determine version for $AppName"
        Write-Output "Will try to install latest..."
        Write-Output "#############################"
    }
    ElseIf (($InstalledVersion -Replace "[\s\.()]") -eq ($AppVersion -Replace "\.")) {
        Write-Output "$AppName is already up-to-date"
        Write-Output "#############################"
        Continue
    }
    Else {
        Write-Output "$AppName requires an update"
    }

    # Download the latest version
    Write-Output "Beginning app download for $AppName"
    $FilePath = Get-InstallPackage -AppName "$AppName" -DownloadUrl $DownloadUrl
    
    # Install the app
    Write-Output "Installing $AppName"
    Set-InstallPackage -AppName "$AppName" -Package "$FilePath"

    # For cleanliness of output
    Write-Output "#############################"
}
