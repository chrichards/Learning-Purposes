# custom settings section
$domainDN = ($($env:USERDNSDOMAIN).Split(".") -join ",DC=").Insert(0,"DC=")
$baseOU = "OU=COMPUTERS,OU=Disabled,$($domainDN)"
$dynamicOU = "$(get-date -f MM)_$(get-date -f MMM)"
$targetOU = "OU=$($dynamicOU),$($baseOU)"

# function: check if the machine is pingable
function global:Get-ConnectionStatus {

    param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true)]
        [ValidateNotNullorEmpty()]
        [String]$ComputerName,

        [Int]$Attempts
    )

    begin {

        $ping = [System.Net.NetworkInformation.Ping]::new()
        $options = [System.Net.NetworkInformation.PingOptions]::new(64,$true)
        $buffer = new-object byte[] 32
        $timeout = [int]100

        if ($Attempts -eq $null) { $Attempts = 1 }

    }

    process {

        try {
            resolve-dnsname -name $ComputerName -erroraction stop | out-null
        }
        catch{
            return $_.exception.message
        }

        for ($i=0; $i -lt $Attempts; $i++) {
            $result = $ping.Send($ComputerName, $timeout, $buffer, $options)
            start-sleep -milliseconds 500              
        }

    }

    end {

        $ping.Dispose()
        return $result

    }

}

# make comparable date
$date = (get-date)
$gt60 = $date.AddDays(-60).ToFileTime()
$gt90 = $date.AddDays(-90).ToFileTime()

# collect all info for processing
$filter = "((enabled -eq 'true') -and ((operatingsystem -like 'Windows*') -and 
(operatingsystem -notlike '*Server*'))) -and (lastlogontimestamp -le $gt60)"
$properties = "lastlogontimestamp","operatingsystem","operatingsystemversion","canonicalname"
$computers = (get-adcomputer -filter $filter -properties $properties) |
    select name,distinguishedname,lastlogontimestamp,operatingsystem,`
        operatingsystemversion,canonicalname

# Create some admin items
$count = $computers.count

# determine work cycle scale
$size = ($count.ToString().Length) - 2
$scale = [math]::pow(10,$size)
if ($scale -gt 1000) {
    $scale = 1000
}

# create array of work cycles
$groups = @()
if ($count % $scale) {
    $a = [math]::truncate($count / $scale)
    $b = ($count % $scale)
} else {
    $a = ($count / $scale)
}
for ($i=1;$i -lt ($a + 1);$i++){
    $total = $i * $scale
    $start = ($total - $scale)
    $end = ($total - 1)
    $temp = [pscustomobject]@{
        Group = $i
        Start = $start
        End = $end
    }
    $groups += $temp
}
if ($b) {
    $temp = [pscustomobject]@{
        Group = $i
        Start = ($end + 1)
        End = ($end + $b)
    }
    $groups += $temp
}

# make a starting point for the jobs
$n = 0

# determine the max pool size
$threadmax = ($groups.Group | select -last 1)
if ($threadmax -gt 10) {
    $threadmax = 10
}

# create array for monitoring all the runspaces
$runspaceCollection = @()

# set up an initial session state object
$initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

# ensure that all runspaces start with the ping function available
# also include the active directory module
$functionDef = get-content function:\Get-ConnectionStatus
$functionEntry = [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new("Get-ConnectionStatus",$functionDef)
$initialSessionState.Commands.Add($functionEntry)
$initialSessionState.ImportPSModule('activedirectory')

# create runspace pool
$runspacePool = [runspacefactory]::CreateRunspacePool(1,$threadmax,$initialSessionState,$Host)
$runspacePool.ApartmentState = "MTA"
$runspacePool.Open()

# make info available for all other threads
$hash = [hashtable]::Synchronized(@{})
$hash.Parameter = $computers

# define what each runspace will be doing
$scriptblock = {
    param(
        $param1,$param2,$param3,
        $param4,$param5,$param6,
        $param7
    )

    $array = [System.Collections.Generic.List[object]]::new()
    for ($i=$param1;$i -le $param2;$i++) {
        $computer = $param3[$i]

        # check to see if the computer should be evaluated
        $status = Get-ConnectionStatus -ComputerName "$($computer.Name)" -Attempts 1

        # if the computer is online or has a DNS entry
        if (($status.Status -eq "Success") -or ($status.Status -eq "TimedOut")) {
            Continue
        }
        
        # define some basic information for reporting
        $dn = $computer.DistinguishedName
        $ou = $computer.CanonicalName -replace $computer.Name
        $idle = ($param6 - [datetime]::FromFileTime($computer.LastLogonTimestamp)).Days

        # establish the target as an ad object
        $ADcomputer = get-adobject -filter "(distinguishedname -eq `"$dn`")"

        # make sure the object can be manipulated
        $ADcomputer | set-adobject -ProtectedFromAccidentalDeletion:$false

        # greater than 60 but less than 90
        if (($computer.LastLogonTimestamp -le $param4) -and `
            ($computer.LastLogonTimestamp -gt $param5)) {
            # disable the computer first, then move it to the designate OU
            $ADcomputer | set-adcomputer -enabled:$false
            $ADcomputer | move-adobject -targetpath $param7

            # add reporting measure
            $line = [pscustomobject]@{
                Computer = $computer.Name
                Status = "Moved/Disabled"
                DaysIdle = $idle
                OS = $computer.OperatingSystem
                Version = $computer.OperatingSystemVersion
                PreviousOU = $ou
            }
        
        }

        if ($computer.LastLogonTimestamp -le $param5) {
            # delete the computer outright; it had its time
            $ADcomputer | remove-adcomputer -confirm:$false

            # add reporting measure
            $line = [pscustomobject]@{
                Computer = $computer.Name
                Status = "Deleted"
                DaysIdle = $idle
                OS = $computer.OperatingSystem
                Version = $computer.OperatingSystemVersion
                PreviousOU = $ou
            }

        }

        $array.Add($line)
        $line = $null
    }
    
    return $array
                
}

# finally, make a storage area for all of our results
$results = [System.Collections.Generic.List[object]]::new()

# begin working
while (!$complete) {

    $start = $groups[$n].Start
    $end = $groups[$n].End
    $parameters = @{
        param1 = $start
        param2 = $end
        param3 = $hash.Parameter
        param4 = $gt60
        param5 = $gt90
        param6 = $date
        param7 = $targetOU
    }

    # 10 is the maximum amount of threads (for your CPUs sake)
    # if there's less than threadmax, add a job
    if (($runspaceCollection.Count -le $threadmax) -and ($n -lt $groups.Count)) {
        # create the powershell object that's going to run the job
        $powershell = [powershell]::Create().AddScript($scriptblock).AddParameters($parameters)

        # add the powerhshell job to the pool
        $powershell.RunspacePool = $runspacePool

        # add monitoring to the runspace collection and start the job
        [collections.arraylist]$runspaceCollection += new-object psobject -property @{
            Runspace = $powershell.BeginInvoke()
            PowerShell = $powershell
        }

        # iterate n
        $n++
    }

    # check the job status and post results
    foreach ($rs in $runspaceCollection.ToArray()) {
        if ($rs.Runspace.IsCompleted) {
            $results.Add($rs.PowerShell.EndInvoke($rs.Runspace))

            # remove the runspace so a new one can be built
            $rs.PowerShell.Dispose()
            $runspaceCollection.Remove($rs)
        }
    }

    # define the complete parameters
    if (($n -eq $groups.Count) -and ($runspaceCollection.Count -eq 0)){
        $complete = $true
    }

}

# Finalize the table and sort it alphabetically
$final = $results.ReadAll() | sort Computer
$final | export-csv "$env:USERPROFILE\Desktop\AD-Inactive-Computer-Cleanup.csv" -notypeinformation
