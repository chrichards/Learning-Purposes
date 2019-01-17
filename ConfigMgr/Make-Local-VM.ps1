Param(
    [Parameter (Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [String]$collectionName,
    [String]$siteCode,
    [String]$siteServer
)

##################### Hyper-V #####################
# Find the ethernet adapter
$wired = Get-NetAdapter -Physical | Where{$_.Name -like "*Ethernet*"}
Write-Host "Will use $wired for VM networking."

# Create a new Virtual Switch
Try{New-VMSwitch -Name "Primary" -AllowManagementOS $true -NetAdapterName $wired.Name -ErrorAction Stop}
Catch{$_.Exception.Message;Break}
Write-Host "New switch 'Primary' has been created."

# First, check to make sure there is enough freespace on the disk
$bytes = (Get-WMIObject -Class win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace
$gigabytes = ($bytes/1073741824)
If($gigabytes -lt 55){Write-Host "Not enough space on disk for VM.";Break}
Write-Host "Creating a virtual hardk disk for the VM to use..."

# Make a VHDX
$path = "$env:PUBLIC\Documents\Hyper-V\Virtual hard disks"
Try{New-VHD -Path "$path\OS.vhdx" -Dynamic -SizeBytes 50GB | 
    Mount-VHD -Passthru | Initialize-Disk -Passthru | 
    New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -Confirm:$false -Force
}
Catch{$_.Exception.Message;Break}
Write-Host "Virtual hard disk created."

# Calculate half of all available RAM that can be assigned to the VM
$bytes = (Get-WMIObject -Class win32_ComputerSystem).TotalPhysicalMemory
$gigabytes = [math]::Round($bytes/1073741824)
$half = ($gigabytes/2)
Write-Host "$half GB will be used for the VM."

# Create the VM
# Create the VM Name
If($env:COMPUTERNAME -like "*-L"){$vmName = $env:COMPUTERNAME -Replace "L","VM"}
Else{$vmName = "$($env:COMPUTERNAME)-VM"}
Write-Host "VM will be named $vmName."

# Create the VM's MAC Address
$hostMAC = (Get-WMIObject -Class win32_NetworkAdapter | Where{$_.Name -eq $wired.InterfaceDescription}).MACAddress
$vmMAC = ("0015"+($hostMAC.Split(":")[2..5])).Replace(" ","")
$properMAC = ($vmMAC -replace '(..)','$1:').Trim(':')
Write-Host "VM will use the following MAC address: $properMAC"

# All other VM parameters
$vm = @{
    Name = $vmName
    MemoryStartupBytes = ($half * 1GB)
    Generation = 2
    VHDPath = "$path\OS.vhdx"
    BootDevice = "NetworkAdapter"
    SwitchName = (Get-VMSwitch | Where{$_.Name -eq "Primary"}).Name
    ErrorAction = Stop
}

# Begin VM creation process
Try{New-VM @vm}
Catch{$_.Exception.Message;Break}
Write-Host "$vmName has been created successfully."

Try{Set-VM -Name $vmName -StaticMemory -ProcessorCount 1 -ErrorAction Stop}
Catch{$_.Exception.Message;Break}
Write-Host "$vmName has been set to 'Static Memory' successfully."

Try{Set-VMFirmware -Name $vmName -EnableSecureBoot Off -ErrorAction Stop}
Catch{$_.Exception.Message;Break}
Write-Host "'SecureBoot' has been disabled successfully."

Try{Set-VMNetworkAdapter -Name $vmName -StaticMacAddress $vmMAC -ErrorAction Stop}
Catch{$_.Exception.Message;Break}
Write-Host "$vmName has been assigned its MAC address successfully."

##################### SCCM #####################
Import-Module ".\ConfigMgr\ConfigurationManager.psd1"
Set-Location -Path "$($siteCode):"

Write-Host "Importing computer to ConfigMgr..."
Try{Import-CMComputerInformation -ComputerName $vmName -MacAddress "$properMAC" -ErrorAction Stop}
Catch{$_.Exception.Message;Break}

Write-Host "Checking for the ResourceID of the imported machine..."
Do{
    $resourceID = (Get-CMDevice -Name $vmName).ResourceID
    Write-Host "Waiting for device to become available..."
    Start-Sleep -Seconds 10
}Until($resourceID)

Write-Host "Adding $resourceID to $collectionName..."
Try{Add-CMDeviceCollectionDirectMembershipRule -CollectionName $collectionName -ResourceId $resourceID}
Catch{$_.Exception.Message;Break}

Write-Host "Updating collection."
$collection = Get-CMDeviceCollection -Name $collectionName
Try{Invoke-WmiMethod -Path "ROOT\SMS\Site_$($siteCode):SMS_Collection.CollectionId='$($collection.CollectionId)'" -Name RequestRefresh -ComputerName $siteServer -ErrorAction Stop}
Catch{$_.Exception.Message;Break}

While($(Get-CMDeviceCollection -Name $collectionName | Select -ExpandProperty CurrentStatus) -eq 5){
    Write-Host "Waiting for collection to update..."
}
Write-Host "Collection updated." 

Write-Host "Checking for device in $collectionName..."
Try{Get-CMDeviceCollectionDirectMembershipRule -CollectionName $collectionName | Where{$_.ResourceID -eq $resourceID} }
Catch{$_.Exception.Message;Break}
Write-Host "Device found in collection."

# Turn VM on
Set-Location -Path "$env:USERPROFILE"
Write-Host "Starting VM."
Try{Start-VM -Name $vmName -ErrorAction Stop}
Catch{$_.Exception.Message;Break}
Write-Host "Done."
