function Check-Connectivity {
    Param(
        [Parameter(Mandatory=$true)]
        $IpAddress
    )

    begin {
        $ping = [System.Net.NetworkInformation.Ping]::new()
        $byte = [byte[]](1..32)
        $timeout = 100
    }

    process {
        $result = $ping.Send($IpAddress,$timeout,$byte)
    }

    end {
        $ping.Dispose()
        return $result.Status
    }
}

function Check-RemoteEnable {
    Param(
        [Parameter(Mandatory=$true)]
        $IpAddress
    )

    begin {
        $socket = [System.Net.Sockets.TcpClient]::new()
    }

    process {
        try {
            $socket.Connect($IpAddress, 135)
            $result = $socket.Connected
        }
        catch {
            $result = $_.exception.message
        }
    }

    end {
        $socket.Close()
        $socket.Dispose()
        return $result
    }
}


    
# check if the "database" exists and declare
# common use paths
$DNSdatabase = 'C:\WOL\DNSinfo.csv'
$MACdatabase = 'C:\WOL\MACinfo.csv'
$errorLog = 'C:\WOL\error.txt'
$data = @()

if (-Not(test-path $DNSdatabase)) {
    start-process powershell -argumentlist "-executionpolicy bypass -File C:\WOL\subnet-gather.ps1" -wait -windowstyle hidden
}

# import the information to work with
$DNSdata = import-csv -path $DNSdatabase

# if the MAC database exists, make sure we're only
# looking at computers we don't have entries for yet
if (test-path $MACdatabase) {
    $MACdata = import-csv -path $MACdatabase

    foreach ($entry in $DNSdata) {
        if ($entry.HostName -in $MACdata.HostName) {
            continue
        }
        else {
            $data += $entry
        }
    }
}
else {
    $data = $DNSdata
}
               
# check to see which computers are available
# and if they're who they say they are
# use some runspaces to make this a bit quicker
$n = 0
$initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$functionDefA = get-content function:\Check-Connectivity
$functionDefB = get-content function:\Check-RemoteEnable
$functionEntryA = new-object System.Management.Automation.Runspaces.SessionStateFunctionEntry -argumentlist "Check-Connectivity",$functionDefA
$functionEntryB = new-object System.Management.Automation.Runspaces.SessionStateFunctionEntry -argumentlist "Check-RemoteEnable",$functionDefB

# add the local functions to the runspaces
$initialSessionState.Commands.Add($functionEntryA)
$initialSessionState.Commands.Add($functionEntryB)

# create array for monitoring all the runspaces
$runspaceCollection = @()

# create runspace pool
$runspacePool = [runspacefactory]::CreateRunspacePool(1,10,$initialSessionState,$host)
$runspacePool.ApartmentState = "MTA"
$runspacePool.Open()

# define what the runspaces are going to do
$scriptblock = {
    param(
        $param1,
        $param2
    )

    if ((Check-Connectivity -IpAddress $param1) -eq 'Success') {
        if (Check-RemoteEnable -IpAddress $param1) {
            $result = [pscustomobject]@{
                Hostname = $param2
                Status = "Ready"
            }
        }
        else {
            $result = [pscustomobject]@{
                Hostname = $param2 
                Status = "Not Configured"
            }
        }
    }
    else {
        $result = [pscustomobject]@{
            Hostname = $param2 
            Status = "Offline"
        }
    }

    return $result

}

# finally, make a storage area for all of our results
$results = [System.Collections.Generic.List[object]]::new()

# begin working
while (!$complete) {
    
    if (($runspaceCollection.Count -le 10) -and ($n -lt $data.Count)) {

        $datum = $data[$n]

        $parameters = @{
            param1 = $datum.IpAddress
            param2 = $datum.HostName
        }

        $powershell = [powershell]::Create().AddScript($scriptblock).AddParameters($parameters)

        # add the powerhshell job to the pool
        $powershell.RunspacePool = $runspacePool

        # add monitoring to the runspace collection and start the job
        [collections.arraylist]$runspaceCollection += new-object psobject -property @{
            Runspace = $powershell.BeginInvoke()
            PowerShell = $powershell
        }

        $n++

    }

    # check the job status and post results
    foreach ($runspace in $runspaceCollection.ToArray()) {
        if ($runspace.Runspace.IsCompleted) {
            $results.Add($runspace.PowerShell.EndInvoke($runspace.Runspace))

            # dispose of the runspace
            $runspace.PowerShell.Dispose()
            $runspaceCollection.Remove($runspace)
        }
    }

    # define the complete parameters
    if (($n -eq $data.Count) -and ($runspaceCollection.Count -eq 0)){
        $complete = $true
    }

}

# the runspaces are now going to do something different
# they will remote to each machine and see if the hostname matches
$scriptblock = {
    param(
        $param1,
        $param2
    )

    try {
        $name = (get-wmiobject -computername $param1 -class win32_ComputerSystem).Name
    }
    catch {
        $name = $param1
        $macAddress = "Could not verify $param1 identity"
    }

    if ($name -eq $param2) {
        
        try {
            $macAddress = (get-wmiobject -computer $param2 `
             -class win32_networkadapterconfiguration -filter "DNSDomain='$($env:USERDNSDOMAIN)'").MacAddress
        }
        catch {
            $macAddress = "Couldn't retrieve MacAddress"
        }

    }
    else { 
        $name = $param1
        $macAddress = "does not belong to $param2" 
    }

    $result = [pscustomobject]@{
        HostName = $name
        MacAddress = $macAddress
    }

    return $result

}

# grab only the online and ready computers
$filter = ($results).Where({$_.Status -eq "Ready"})

# compile a new data array using the filter
$data = @()
foreach ($entry in $DNSdata) {
    if ($entry.HostName -in $filter.HostName) {
        $data += $entry
    }
}

# reset the counters
$n = 0
$complete = $null

# a new area to hold the results of the second round
$results = [System.Collections.Generic.List[object]]::new()

# begin working
while (!$complete) {
    
    if (($runspaceCollection.Count -le 10) -and ($n -lt $data.Count)) {

        $datum = $data[$n]

        $parameters = @{
            param1 = $datum.IpAddress
            param2 = $datum.HostName
        }

        $powershell = [powershell]::Create().AddScript($scriptblock).AddParameters($parameters)

        # add the powerhshell job to the pool
        $powershell.RunspacePool = $runspacePool

        # add monitoring to the runspace collection and start the job
        [collections.arraylist]$runspaceCollection += new-object psobject -property @{
            Runspace = $powershell.BeginInvoke()
            PowerShell = $powershell
        }

        $n++

    }

    # check the job status and post results
    foreach ($runspace in $runspaceCollection.ToArray()) {
        if ($runspace.Runspace.IsCompleted) {
            $results.Add($runspace.PowerShell.EndInvoke($runspace.Runspace))

            # dispose of the runspace
            $runspace.PowerShell.Dispose()
            $runspaceCollection.Remove($runspace)
        }
    }

    # define the complete parameters
    if (($n -eq $data.Count) -and ($runspaceCollection.Count -eq 0)){
        $complete = $true
    }

}

# filter out the erroneous entries and keep the
# good ones
$output = @()
$errorOut = @()

foreach ($result in $results) {

    if ($result.HostName -match '(?:\d{1,3}\.){3}\d{1,3}') {
        $errorOut += $result
    }

    elseif ($result.MacAddress -notmatch '^([0-9a-f]{2}:){5}([0-9a-f]{2})$') {
        $errorOut += $result
    }

    else {
        $output += $result
    }

}

# get rid of old entries in the MAC database
foreach ($entry in $MACdata) {

    if ($entry.HostName -notin $DNSdata.HostName) {
        continue
    }
    else {
        $output += $entry
    }

}

if ($errorOut) {
    $errorOut | out-file $errorLog -force
}

$output | export-csv "C:\WOL\MACinfo.csv" -notypeinformation -Append

# remove the DNS data. We always want the freshest data
remove-item $DNSdatabase -force
