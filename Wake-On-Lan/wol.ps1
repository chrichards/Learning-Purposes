param (
    [CmdletBinding()]
    [Parameter(Mandatory=$true)]
    [ValidateNotNullorEmpty()]
    [string[]]$mac,
    [string[]]$computer
)

# check if input is any of the following types
# aa:bb:cc:00:11:22
# aa-bb-cc-00-11-22
# aabb.cc00.1122
# aabbcc001122
$patterns = @(
    '^([0-9a-f]{2}:){5}([0-9a-f]{2})$',
    '^([0-9a-f]{2}-){5}([0-9a-f]{2})$',
    '^([0-9a-f]{4}\.){2}([0-9a-f]{4})$',
    '^([0-9a-f]{12})$'
)

if ($mac -notmatch ($patterns -join '|')) {
    write-output "Syntax error with MAC"
    break
}

# set the format so there are no special characters
if ($mac -match '[.-]') {
    $mac = $mac -replace '[.-]'
}

# insert colons for a 'proper' MAC address format
if ($mac -notmatch "[:]") {
    $mac = $mac -replace '(..(?!$))','$1:'
}


# create a byte array out of the MAC address
$macArray = $mac -split ':' | % { [byte] "0x$_" }

# create a 'magic packet' with the MAC byte array
# the 'magic packet' MUST contain the MAC address of
# the destination computer, otherwise WoL will not work
[byte[]] $packet = (,0xFF * 6) + ($macArray * 16)

# WoL uses a UDP client
$udp = new-object system.net.sockets.udpclient

# create a "connection" to the remote device
# if $computer is specified, try to connect either by DNS name or
# ip address. Otherwise, a broadcast will be created
# note: ip/host will only work on Out-of-Band configured devices
if ($computer) {

    if ($computer -match '(?:\d{1,3}\.){3}\d{1,3}') {
        # parse the ip address into a useable object
        $ip = [system.net.ipaddress]::parse($computer)

        # create a 'socket' object
        $socket = [system.net.ipendpoint]::new($ip,7)

        # send the 'magic packet' to the socket
        $udp.Send($packet,$packet.length,$socket)
    }
    else {
        # send the 'magic packet' using the hostname
        $udp.Send($packet,$packet.length,$computer,7)
    }

}
else {
    # everyone in the subnet will get the packet
    $udp.Connect([system.net.ipaddress]::broadcast,7)
    
    # send the packet 
    $udp.send($packet,$packet.length)
}

# close and dispose of the udp client
$udp.close()
$udp.dispose()
