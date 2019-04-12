# Drop the necessary exe file into place
Copy-Item -Path ".\srvany.exe" -Destination "C:\Windows\System32" -Force

# Create the service connector
$syncserver = "$env:ProgramFiles\Common Files\Apple\Mobile Device Support\SyncServer.exe"
$syncserver64 = "${env:ProgramFiles(x86)}\Common Files\Apple\Mobile Device Support\SyncServer.exe"

If(Test-Path $syncserver64){$use = $syncserver64}
ElseIf(Test-Path $syncserver){$use = $syncserver}
If(!$use){Exit 1}

Try{Start-Process sc -ArgumentList 'create AppleSyncServer binPath= "C:\Windows\System32\srvany.exe" start= auto' -Wait -ErrorAction Stop}
Catch{$_.Exception.Message; Exit 1}

$services = "HKLM:\SYSTEM\CurrentControlSet\Services"
$applesyncserver = "$services\AppleSyncServer"

Try{New-Item -Path $applesyncserver -Name "Parameters" -Force -ErrorAction Stop}
Catch{$_.Exception.Message; Exit 1}

Try{New-ItemProperty -Path "$applesyncserver\Parameters" -Name "Application" -PropertyType String -Value "$use" -Force -ErrorAction Stop}
Catch{$_.Exception.Message; Exit 1}

# Allow services to be start/stop by users
$acl = "D:(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;DU)(A;;CCLCSWLOCRRC;;;IU)S:(AU;FA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)"

Try{Start-Process sc -ArgumentList "sdset","Apple Mobile Device Service","$acl" -Wait -ErrorAction Stop}
Catch{$_.Exception.Message; Exit 1}

Try{Start-Process sc -ArgumentList "sdset","iPod Service","$acl" -Wait -ErrorAction Stop}
Catch{$_.Exception.Message; Exit 1}

Try{Start-Process sc -ArgumentList "sdset","AppleSyncServer","$acl" -Wait -ErrorAction Stop}
Catch{$_.Exception.Message; Exit 1}

$icon = "C:\Users\Public\Desktop\iTunes.lnk"
if(test-path $icon){
    remove-item $icon -force
}

$itunes = 'c:\program files\iTunes'
$itunes86 = 'c:\program files (x86)\iTunes'

if(test-path "$itunes\iTunesHelper.exe"){
    remove-item -path "$itunes\iTunesHelper.exe" -force
}
if(test-path "$itunes86\iTunesHelper.exe"){
    remove-item -path "$itunes86\iTunesHelper.exe" -force
}

Start .\iMazing-CLI_2.9.1-9797-Windows.exe -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NOCANCEL /NORESTART /FORCECLOSEAPPLICATIONS /NOICONS" -wait
Copy-Item '.\iOS Backup Utility.exe' -Destination 'C:\Program Files\DigiDNA\iMazing-CLI'
Copy-Item '.\iOS Backup Utility.lnk' -Destination 'C:\Users\Public\Desktop'

Start 'C:\Program Files\DigiDNA\iMazing-CLI\iMazing-CLI.exe' -ArgumentList '--activate [activation code]' -Wait
