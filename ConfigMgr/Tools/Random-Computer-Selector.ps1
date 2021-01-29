Param (
    $site
)

# import the module
$path = 'C:\Program Files (x86)\Microsoft Endpoint Manager\AdminConsole\bin\ConfigurationManager\ConfigurationManager.psd1'

try { Import-Module $path -ErrorAction Stop }
catch { Write-Output "$error"; Exit 1 }

# change to the proper site
Set-Location -Path "$($site):\"

# get all the computers
$all_computers = Get-CMResource -ResourceType System -Fast

# get all windows computers
$all_windows = $all_computers.Where{($_.OperatingSystemNameAndVersion -like "*Workstation*") -or
($_.OperatingSystemNameAndVersion -like "*Windows 10*")}

# get all hardware models (lenovo specialness)
# some people might not have this setup in their environment
# in which case, they can just use SMS_G_System_COMPUTER_SYSTEM for Model info
$wql = @"
select distinct
  SMS_G_System_CCM_COMPUTERSYSTEMEXTENDED2.Name,
  SMS_G_System_CCM_COMPUTERSYSTEMEXTENDED2.SystemFamily
from
  SMS_R_System inner join SMS_G_System_CCM_COMPUTERSYSTEMEXTENDED2
on
  SMS_G_System_CCM_COMPUTERSYSTEMEXTENDED2.ResourceID = SMS_R_System.ResourceId
"@

$all_computers_and_models = Invoke-CMWmiQuery -Query $wql
$all_models = ($all_computers_and_models).SystemFamily | Sort-Object | Get-Unique

Set-Location -Path $env:userprofile

# gather up all the users
$searcher = [System.DirectoryServices.DirectorySearcher]::new()
$searcher.Filter = "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))" # the end bit excludes disabled user accounts
[void]$searcher.PropertiesToLoad.Add("cn")
[void]$searcher.PropertiesToLoad.Add("mail")
[void]$searcher.PropertiesToLoad.Add("samaccountname")
[void]$searcher.PropertiesToLoad.Add("department")
[void]$searcher.PropertiesToLoad.Add("title")
$searcher.PageSize = 1000
$all_users = ($searcher.FindAll()).Properties

# define the unique departments
$departments = $all_users.department | Sort-Object | Get-Unique

###############################################################################################################

# runspace nonsense
# make a starting point for the jobs
$n = 0

# create array for monitoring all the runspaces
$runspaceCollection = @()

# set up an initial session state object
$initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

# stuff the user and computer collections into those runspaces
$collectionEntryA = [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new("all_users",$all_users,$null)
$collectionEntryB = [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new("all_windows",$all_windows,$null)
$collectionEntryC = [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new("all_computers_and_models",$all_computers_and_models,$null)
$initialSessionState.Variables.Add($collectionEntryA)
$initialSessionState.Variables.Add($collectionEntryB)
$initialSessionState.Variables.Add($collectionEntryC)

# create runspace pool
$runspacePool = [runspacefactory]::CreateRunspacePool(1,10,$initialSessionState,$Host)
$runspacePool.ApartmentState = "STA"
$runspacePool.Open()

# somewhere to store the selected computers
$results = [System.Collections.ArrayList]::new()

# what are the spaces gon' do?
$scriptblock = {
    Param (
        $param1,
        $param2
    )

    $choose_from = $all_windows.Where{$_.Name -in $param1.Name}

    # randomly select a computer
    # but make sure it doesn't belong to a high ranking exec or something
    Do {
        If ($choose_from.Count -lt 5) {
            # not werf
            Break
        }
        Else {
            $randomly_selected = Get-Random -InputObject $choose_from -Count 1
        }

        $selected = ($randomly_selected | Select-Object -Property Name,LastLogonUserName,ResourceId,SMSUniqueIdentifier)

        If ($selected.Name -in $param2.ComputerName) {
            # Already exists; skip it
            Continue
        }

        $user = $selected.LastLogonUserName
        $user_check = $all_users.Where{$_.samaccountname -like $user}

        If (($user_check.title -like "*Chief*") -or
            ($user_check.title -like "*Director*") -or
            ($user_check.title -like "*President*")) {
            # skip this user
            Continue
        }
        ElseIf (!$user) {
            # heck it, add the computer!
            $department = $null
            $done = $true
        }
        Else {
            # annotate which department has been used
            $department = $user_check.department
            $done = $true
        }

        If ($done) {
            $filter = ($all_computers_and_models | Select-Object -Property Name,SystemFamily)
            $model = $filter.Where{$_.Name -like $selected.Name} | Select-Object -Property SystemFamily
            $result = [PsCustomObject]@{
                ComputerName = $selected.Name
                Model        = $model.SystemFamily
                User         = $selected.LastLogonUserName
                Department   = $department
                ResourceId   = $selected.ResourceId
                SMSUniqueId  = $selected.SMSUniqueIdentifier
            }
        }
        
        #$randomly_selected = $user = $user_check = $selected = $department = $null                

    } Until ($done -eq $true)

    If ($result) {
        Return $result
    }
}

# begin work
While (!$complete) {
    
    $parameters = @{
        param1 = $all_computers_and_models.Where{$_.SystemFamily -eq $all_models[$n]}
        param2 = $results
    }

    If (($runspaceCollection.Count -le 10) -and ($n -lt $all_models.Count)) {
        Write-Host "Adding job $n"
        # create the powershell object that's going to run the job
        $powershell = [powershell]::Create().AddScript($scriptblock).AddParameters($parameters)

        # add the powerhshell job to the pool
        $powershell.RunspacePool = $runspacePool

        # add monitoring to the runspace collection and start the job
        [collections.arraylist]$runspaceCollection += New-Object PsObject -Property @{
            Runspace = $powershell.BeginInvoke()
            PowerShell = $powershell
        }

        # iterate n
        $n++
    }

    # check the job status and post results
    ForEach ($runspace in $runspaceCollection.ToArray()) {
        If ($runspace.Runspace.IsCompleted) {
            $results.Add($runspace.PowerShell.EndInvoke($runspace.Runspace)[0])

            # remove the runspace so a new one can be built
            $runspace.PowerShell.Dispose()
            $runspaceCollection.Remove($runspace)
            Write-Host "Job complete"
        }
    }

    # define the complete parameters
    If (($n -eq $all_models.Count) -and ($runspaceCollection.Count -eq 0)){
        $complete = $true
    }
    
}

# now we need to see which departments haven't been represented yet
$complete = $null
$used = ($results.Department) | Sort-Object | Get-Unique
$leftover = $departments.Where{$_ -notin $used}
$n = 0

# NOW what are the spaces gon' do?
$scriptblock = {
    Param (
        $param1,
        $param2
    )

    $choose_from = $all_windows.Where{$_.Name -notin $param2.ComputerName}
    $department_users = $users.Where{$_.department -like "*$param2*"}
    $choose_from_filtered = $choose_from.Where{$_.LastLogonUserName -in $department_users.samaccountname}

    # randomly select a computer
    # but make sure it doesn't belong to a high ranking exec or something
    Do {
        If ($choose_from_filtered.Count -lt 5) {
            # not werf
            Break
        }
        Else {
            $randomly_selected = Get-Random -InputObject $choose_from_filtered -Count 1
        }

        $selected = ($randomly_selected | Select-Object -Property Name,LastLogonUserName,ResourceId,SMSUniqueIdentifier)

        If ($selected.Name -in $param2.ComputerName) {
            # Already exists; skip it
            Continue
        }

        $user = $selected.LastLogonUserName
        $user_check = $all_users.Where{$_.samaccountname -like $user}

        If (($user_check.title -like "*Chief*") -or
            ($user_check.title -like "*Director*") -or
            ($user_check.title -like "*President*")) {
            # skip this user
            Continue
        }
        ElseIf (!$user) {
            # heck it, add the computer!
            $department = $null
            $done = $true
        }
        Else {
            # annotate which department has been used
            $department = $user_check.department
            $done = $true
        }

        If ($done) {
            $filter = ($all_computers_and_models | Select-Object -Property Name,SystemFamily)
            $model = $filter.Where{$_.Name -like $selected.Name} | Select-Object -Property SystemFamily
            $result = [PsCustomObject]@{
                ComputerName = $selected.Name
                Model        = $model.SystemFamily
                User         = $selected.LastLogonUserName
                Department   = $department
                ResourceId   = $selected.ResourceId
                SMSUniqueId  = $selected.SMSUniqueIdentifier
            }
        }
        
        $randomly_selected = $user = $user_check = $selected = $department = $null                

    } Until ($done -eq $true)

    If ($result) {
        Return $result
    }
} 

Write-Host "`r`nNext set of runspaces"
# round 2, fight!
While (!$complete) {
    
    $parameters = @{
        param1 = $leftover[$n]
        param2 = $results
    }

    If (($runspaceCollection.Count -le 10) -and ($n -lt $leftover.Count)) {
        Write-Host "Adding job $n"
        # create the powershell object that's going to run the job
        $powershell = [powershell]::Create().AddScript($scriptblock).AddParameters($parameters)

        # add the powerhshell job to the pool
        $powershell.RunspacePool = $runspacePool

        # add monitoring to the runspace collection and start the job
        [collections.arraylist]$runspaceCollection += New-Object PsObject -Property @{
            Runspace = $powershell.BeginInvoke()
            PowerShell = $powershell
        }

        # iterate n
        $n++
    }

    # check the job status and post results
    ForEach ($runspace in $runspaceCollection.ToArray()) {
        If ($runspace.Runspace.IsCompleted) {
            $results.Add($runspace.PowerShell.EndInvoke($runspace.Runspace)[0])

            # remove the runspace so a new one can be built
            $runspace.PowerShell.Dispose()
            $runspaceCollection.Remove($runspace)
            Write-Host "Job complete"
        }
    }

    # define the complete parameters
    If (($n -eq $leftover.Count) -and ($runspaceCollection.Count -eq 0)){
        $complete = $true
    }
    
}

$results | Export-Csv "$env:userprofile\desktop\test.csv" -NoTypeInformation
