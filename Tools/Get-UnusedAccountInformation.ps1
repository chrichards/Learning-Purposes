# ExO Information
$Tenant = [Your Tenant here]
$AppId  = [Setup an Azure SPN and put the AppID here]
$Certificate = Get-ChildItem -Path "cert:\LocalMachine\My" | Where-Object {$_.Thumbprint -eq [Some thumbprint of the cert you setup with the Azure SPN]}

# Runspace Info
$threadmax = 20
$n = 0

#######################################################################################
##                                  Main                                             ##
#######################################################################################
# Import Active Directory
try {
    Import-Module activedirectory -ErrorAction Stop
} catch {
    $_.Exception.Message
    break
}
# Get all users that are enabled
$all_users = Get-AdUser -Filter {Enabled -eq $true} -Properties *

# Of those users, which accounts haven't logged on within the past 30 days?
$comparison_date = (Get-Date).AddDays(-30)
$users_no_logon_past_30days = $all_users.Where{[datetime]::FromFileTime($_.lastLogonTimestamp) -lt $comparison_date}

# Take all of the previous info and put it in a table that doesn't change and can be shared with runspaces
$hashtable = [hashtable]::Synchronized(@{})
$hashtable.NoLogonIn30 = $users_no_logon_past_30days

# Place to store cleaned-up information
$results = New-Object Collections.ArrayList
$errors = @()

# How many users are we working with? This will define how runspace work is divided
$count = $users_no_logon_past_30days.Count

# Connect to ExO
try {
    Connect-ExchangeOnline -Organization $Tenant -AppId $AppId -CertificateThumbprint $Certificate.Thumbprint -ErrorAction Stop
} catch {
    $_.Exception.Message

    # Can't do the thing if we can't connect
    exit 1
}

#######################################################################################
##                                Runspace Setup                                     ##
#######################################################################################
# Create array for monitoring all the runspaces
$runspaceCollection = @()

# Set up an initial session state object
$initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

# Ensure that all runspaces start with necessary resources
$variableEntry1 = [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new("NoLogonIn30",$hashtable.NoLogonIn30,$null)
$initialSessionState.Variables.Add($variableEntry1)
$initialSessionState.ImportPSModule('ExchangeOnlineManagement')

# create runspace pool
$runspacePool = [runspacefactory]::CreateRunspacePool(1,$threadmax,$initialSessionState,$Host)
$runspacePool.ApartmentState = "MTA"
$runspacePool.ReuseThread = $true
$runspacePool.Open()

# What are the runspaces going to be doing?
$scriptblock = {
    Param (
        $Index
    )

    # shouldn't be possible to have variable polituion but take no chances
    # absolutely ensure a clean working environment
    $variables = @(
        "user", "username", "lastLogon", "lastLogonTimestamp", "mail",
        "logon", "mailbox", "identity", "recipient", "mailboxStats",
        "mailboxStatsAvailable", "mailboxScope", "mailboxType", "actionTime",
        "folderStats", "folderStatsAvailable", "inbox", "outbox", "received",
        "sent", "information"
    )
    Clear-Variable -Name $variables -Force -ErrorAction SilentlyContinue

    # begin declarations and processing
    $user = $NoLogonIn30[$Index]
    $username = [string]$user.Item('sAMAccountName')
    $lastLogon = [string]$user.Item('lastLogon')
    $lastLogonTimestamp = [string]$user.Item('lastLogonTimestamp')
    $mail = [string]$user.Item('mail')
    Clear-Variable -Name ("recipient", "mailbox", "actionTime", "mailboxScope", "mailboxType", "sent", "received")

    # check both the local DC timestamp and the replicated timestamp
    # if neither are populated, the account has never had a login
    if (-Not($lastLogon)) {
        if (-Not($lastLogonTimestamp)) {
            $logon = "Never"
        } else {
            $logon = [datetime]::FromFileTime($lastLogonTimestamp)
        }
    } elseif ($lastLogon -and $lastLogonTimestamp) {
        # which one is newer?
        if ($lastLogon -gt $lastLogonTimestamp) {
            $logon = [datetime]::FromFileTime($lastLogon)
        } else {
            $logon = [datetime]::FromFileTime($lastLogonTimestamp)
        }
    } else {
        $logon = [datetime]::FromFileTime($lastLogon)
    }

    # check and see if the mailbox is being used or not
    if (-Not($mail)) {
        $mailbox = $false
        $recipient = $false
    } else {
        try {
            $identity = Get-EXORecipient -Identity $mail -ErrorAction Stop
            $recipient = $true
        } catch {
            $recipient = $false
        }
    }

    if ($recipient) {
        try {
            Get-EXOMailbox -Identity $identity -ErrorAction Stop
            $mailbox = $true
        } catch {
            $mailbox = $false
        }
    }

    if ($mailbox) {
        try {
            $mailboxStats = Get-EXOMailboxStatistics -Identity $identity -Properties LastUserActionTime,MailboxType,MailboxTypeDetail -ErrorAction Stop
            $mailboxStatsAvailable = $true
        } catch {
            $mailboxStatsAvailable = $false
        }
        
        if ($mailboxStatsAvailable) {
            [string]$mailboxScope = $mailboxStats.MailboxType
            [string]$mailboxType = $mailboxStats.MailboxTypeDetail

            if ($mailboxStats.LastUserActionTime) {
                $actionTime = Get-Date $mailboxStats.LastUserActionTime -UFormat "%D %r"
            } else {
                $actionTime = "No Interactions"
            }

            try {
                $folderStats = (Get-EXOMailboxFolderStatistics -Identity $identity -IncludeOldestAndNewestItems -ErrorAction Stop).Where{$_.Name -Match "Inbox|Sent"}
                $folderStatsAvailable = $true
            } catch {
                $folderStatsAvailable = $false
            }

            if ($folderStatsAvailable) {
                $inbox = $folderStats.Where{$_.Name -match "Inbox"}
                $outbox = $folderStats.Where{$_.Name -match "Sent"}

                if ($inbox.NewestItemReceivedDate) { 
                    $received = Get-Date $inbox.NewestItemReceivedDate -UFormat "%D %r"
                } else {
                    $received = "No mail ever received"
                }

                if ($outbox.NewestItemReceivedDate) {
                    $sent = Get-Date $outbox.NewestItemReceivedDate -UFormat "%D %r"
                } else {
                    $sent = "No mail ever sent"
                }
            }
        }   
    }

    $information = [PsCustomObject]@{
        Username                    = $username
        LastAuthentication          = $logon
        Mail                        = $mail
        IsRecipient                 = $recipient
        MailboxExists               = $mailbox
        MailboxInformationAvailable = $mailboxStatsAvailable
        MailboxScope                = $mailboxScope
        MailboxType                 = $mailboxType
        LastMailInteraction         = $actionTime
        LastReceivedMail            = $received
        LastSentMail                = $sent
    }

    return $information
} # End of scriptblock

while (!$complete) {
    $parameters = @{
        Index = $n
    }

    # if there's less than threadmax, add a job
    if (($runspaceCollection.Count -le $threadmax) -and ($n -lt $count)) {
        Write-Output "Starting index $n of $count"

        # create the powershell object that's going to run the job
        $powershell = [powershell]::Create().AddScript($scriptblock).AddParameters($parameters)

        # add the powerhshell job to the pool
        $powershell.RunspacePool = $runspacePool

        # add monitoring to the runspace collection and start the job
        [collections.arraylist]$runspaceCollection += new-object psobject -property @{
            Runspace = $powershell.BeginInvoke()
            PowerShell = $powershell
            Index = $n
        }

        # iterate n
        $n++
    }

    # check the job status and post results
    foreach ($runspace in $runspaceCollection.ToArray()) {
        if ($runspace.Runspace.IsCompleted) {
            Write-Output "Finished index $($runspace.Index)"
            $results.Add($runspace.PowerShell.EndInvoke($runspace.Runspace)) | Out-Null

            # remove the runspace so a new one can be built
            $runspace.PowerShell.Dispose()
            $runspaceCollection.Remove($runspace)
        }
    }

    # define the complete parameters
    if (($n -eq $count) -and ($runspaceCollection.Count -eq 0)){
        Write-Output "Runspace jobs have completed."
        $complete = $true
    }

}

$final_output = $results.ReadAll()
$final_output | Export-Csv "$env:UserProfile\Desktop\Stale-User-Aduit.csv" -NoTypeInformation
