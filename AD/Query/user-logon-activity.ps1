# collect all user info in the main thread
$searcher = [System.DirectoryServices.DirectorySearcher]::new()
$searcher.Filter = "(&(objectCategory=person)(objectClass=user))"
$searcher.PropertiesToLoad.Add("name")
$searcher.PropertiesToLoad.Add("samaccountname")
$searcher.PropertiesToLoad.Add("useraccountcontrol")
$searcher.PropertiesToLoad.Add("lastlogontimestamp")
$searcher.PropertiesToLoad.Add("employeetype")
$users = ($searcher.FindAll()).Properties

# define how many objects needs to be processed
$count = $users.Count

# create array of work cycles
$groups = @()
if ($count % 1000) {
    $a = [math]::truncate($count / 1000)
    $b = ($count % 1000)
} else {
    $a = ($count / 1000)
}
for ($i=1;$i -lt ($a + 1);$i++){
    $total = $i * 1000
    $start = ($total - 1000)
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

# create array for monitoring all the runspaces
$rsc = @()

# create runspace pool
$rsp = [runspacefactory]::CreateRunspacePool(1,10)
$rsp.ApartmentState = "MTA"
$rsp.Open()

# make info available for all other threads
$hash = [hashtable]::Synchronized(@{})
$hash.Parameter = $users

# define what each runspace will be doing
$scriptblock = {
    param(
        $param1,
        $param2,
        $param3
    )

    $array = [System.Collections.Generic.List[object]]::new()
    for ($i=$param1;$i -le $param2;$i++) {
        $user = $param3[$i]

        # when was the last time the user logged on
        if ($user.lastlogontimestamp) {
            $loggedIn = $false
            $time = [datetime]::FromFileTime([long]($user.lastlogontimestamp | 
                out-string)) -replace "`r`n"
            
            if ($time -gt (Get-Date).adddays(-90)) {
                $over90 = $true
            } else { 
                $over90 = $false
            }
        } else { 
            $loggedIn = $true
        }

        # what type of employee is it
        if ($user.employeetype) { 
            $EmployeeType = ($user.employeetype)[0]
        } else { 
            $EmployeeType = 'N/A'
        }

        # is the object enabled
        $value = [convert]::ToString([int32]($user.useraccountcontrol | out-string),2)
        $bool = [boolean]([int]$value.Substring(($value.length - 2),1))

        if ($bool -eq $true) {
            $enabled = $false
        } else {
            $enabled = $true
        }

        $table = [pscustomobject]@{ 
            Name = ($user.name)[0]
            SamAccountName = ($user.samaccountname)[0]
            Enabled = $enabled
            EmployeeType = $EmployeeType
            NeverLoggedIn = $loggedIn
            LoggedInOver90 = $over90
            LastLogonDate = $time

        } 
        $array.Add($table)
        $user = $null
        $table = $null
        $searcher.Dispose()
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
    }

    # there can only be 8 threads running at once
    # if there's less than 8, add a job
    if (($rsc.Count -le 10) -and ($n -lt $groups.Count)) {
        # create the powershell object that's going to run the job
        $powershell = [powershell]::Create().AddScript($scriptblock).AddParameters($parameters)

        # add the powerhshell job to the pool
        $powershell.RunspacePool = $rsp

        # add monitoring to the runspace collection and start the job
        [collections.arraylist]$rsc += new-object psobject -property @{
            Runspace = $powershell.BeginInvoke()
            PowerShell = $powershell
        }

        # iterate n
        $n++
    }

    # check the job status and post results
    foreach ($rs in $rsc.ToArray()) {
        if ($rs.Runspace.IsCompleted) {
            $results.Add($rs.PowerShell.EndInvoke($rs.Runspace))

            # remove the runspace so a new one can be built
            $rs.PowerShell.Dispose()
            $rsc.Remove($rs)
        }
    }

    # define the complete parameters
    if (($n -eq $groups.Count) -and ($rsc.Count -eq 0)){
        $complete = $true
    }

}

# post results to user's desktop
$results | format-table -autosize | out-string -width 4096 |
out-file "$env:userprofile\Desktop\ADUsers-Processed.txt"
