# flush the dns cache so we get the most current data
Clear-DnsClientCache

# who am I and what subnet am I operating from?
# get the local ip address
$ip = get-netipaddress -addressfamily IPv4 -PrefixOrigin Dhcp -InterfaceAlias Ethernet | select *

# handy numbers for binary math
$netMath = @(128,64,32,16,8,4,2,1)

# first, generate the subnet mask
$subnetMask = @()
$n = 0

for ($i=0;$i -lt $ip.PrefixLength;$i++) {
    
    $octet = $octet + $netMath[$n]

    if ($n -eq 7) {

        $subnetMask += $octet
        $octet = $null
        $n = 0

    }
    else { $n++ }

}

if ($octet) { $subnetMask += $octet }
if ($subnetMask.Count -lt 4) {
    while($subnetMask.Count -lt 4) {
        $subnetMask += 0
    }
}

$subnetMask = $subnetMask -join "."

# next, generate the wildcard mask
$hostBits = 32 - $ip.PrefixLength
$wildcardMask = @()
$n = 0
$octet = $null
[array]::Reverse($netMath) # invert the array for calculations

for ($i=0;$i -lt $hostBits;$i++) {
    
    $octet = $octet + $netMath[$n]

    if ($n -eq 7) {

        $wildcardMask += $octet
        $octet = $null
        $n = 0

    }
    else { $n++ }

}

if ($octet) { $wildcardMask += $octet }
if ($wildcardMask.Count -lt 4) {
    while($wildcardMask.Count -lt 4) {
        $wildcardMask += 0
    }
}

# the array is backwards, so we'll fix that
[array]::Reverse($wildcardMask)
$wildcardMask = $wildcardMask -join "."

# use a binary comparison to calculate the network address
[string]$localhostAddress = $ip.ipAddress
$networkAddress = [ipaddress](([ipaddress]$localhostAddress).Address -band ([ipaddress]$subnetMask).Address)

# using a binary or, calculate the broadcast address
$broadcastAddress = [ipaddress](([ipaddress]$localhostAddress).Address -bor ([ipaddress]$wildcardMask).Address)

# finally, we need an array of all the addresses that we
# would compare against with our DNS query
$networkBytes = $networkAddress.GetAddressBytes()
[array]::Reverse($networkBytes) # the array is inverted for iteration purposes
$networkINT = [bitconverter]::touint32($networkBytes, 0)

$broadcastBytes = $broadcastAddress.GetAddressBytes()
[array]::Reverse($broadcastBytes)
$broadcastINT = [bitconverter]::touint32($broadcastBytes, 0)

$allAddresses = @()
for ($i = $networkINT + 1; $i -lt $broadcastINT; $i++) {
    $addressBytes = [bitconverter]::getbytes($i)
    [array]::reverse($addressBytes)
    $address = new-object ipaddress(,$addressBytes)
    $allAddresses += $address
}

# get all the DNS records of machines in your subnet
$logonServer = $env:LOGONSERVER -replace "[\\]"
$dnsRecords = (get-DnsServerResourceRecord -ZoneName $env:USERDNSDOMAIN -ComputerName $logonServer).where({
    $($_.RecordData).IPv4Address -in $allAddresses})

$dnsRecords | select HostName,@{n='IpAddress';e={$($_.RecordData).IPv4Address}} | export-csv 'C:\WOL\DNSinfo.csv' -notypeinformation
