Param(
    [parameter(Mandatory=$true)]
    [ValidateNotNullorEmpty()]
    [string]$Server,

    [parameter(Mandatory=$true)]
    [ValidateNotNullorEmpty()]
    [int]$Port,

    [parameter(Mandatory=$true)]
    [ValidateNotNullorEmpty()]
    [ValidateSet(1,2,3,4,5,6,7,8,9,10,11,12)]
    [int]$Month,
    
    [parameter(Mandatory=$true)]
    [ValidateNotNullorEmpty()]
    [int]$Year
)

$previous_month = (Get-Date "$Month/1/$Year").AddMonths(-1)
$next_month = (Get-Date "$Month/1/$Year").AddMonths(1)

$report = @()
# Load the DLL that allows for WSUS connection; establish connection the WSUS server
[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
$WSUS = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($Server,$false,$Port)

# Define the computer scope and the update scope; only updates that you want to install
$computer_scope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
$update_scope = New-Object Microsoft.UpdateServices.Administration.UpdateScope;
$update_scope.UpdateApprovalActions = [Microsoft.UpdateServices.Administration.UpdateApprovalActions]::Install

cls
Write-Host "Please wait while information is collected from the WSUS database..."

# Get updates that are defined by the month/year given by user
$updates = $WSUS.GetUpdates($update_scope) | Where{($_.ArrivalDate -gt $previous_month) -and ($_.ArrivalDate -lt $next_month)}

$update_count = 1
$update_total = $updates.Count
Write-Host "Working with $update_total update(s)."; Start-Sleep -Seconds 5
Write-Host "These are the updates being checked for $month/$year."; Start-Sleep -Seconds 5
$updates | Select Title | Format-Table -AutoSize
Write-Host "Please wait while individual data is collected for each server."

ForEach($update in $updates){
    $temp = $update.GetUpdateInstallationInfoPerComputerTarget($computer_scope)
    $temp_count = 1
    $temp_total = $temp.Count
    $Position = 0
    $overall_percent = (($update_count/$update_total)*100)
    Write-Progress -Activity "Overall progress:" -Status "$overall_percent %" -PercentComplete $overall_percent -Id 1
    ForEach($item in $temp){
        Write-Progress -Activity "Processing Update $update_count of $update_total" -Status "Server $temp_count of $temp_total" -PercentComplete (($Position/$temp_total)*100) -ParentId 1
        $comp = $WSUS.GetComputerTarget($item.ComputerTargetID)
        
        $info = "" | Select ComputerName,OS,UpdateTitle,UpdateInstallationStatus
        $info.ComputerName = $comp.FullDomainName
        $info.OS = $comp.OSDescription
        $info.UpdateTitle = $update.Title
        $info.UpdateInstallationStatus = $item.UpdateInstallationState
        
        $report += $info
        $Position++;$temp_count++
    }
    $update_count++
}

Write-Host "Dumping data into a raw file"
$report | Export-CSV -Path "$env:UserProfile\Desktop\wsus-report.csv" -Append -NoTypeInformation
Write-Host "Done!"
