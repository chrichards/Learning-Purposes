Param (
    [int]$PercentThreshold,
    [string]$Email,
    [string]$SmtpServer
)

# Function for converting storage size to appropriate formats
Function Get-BytesUnit {
    Param ( [long]$Bytes )

    # Bytes
    If ($Bytes -lt 1024) { $Unit = 'Bytes'; $Exp = 0 }
    # Kilobytes
    ElseIf (($Bytes -ge 1024) -and ($Bytes -lt [math]::Pow(1024,2))) { $Unit = 'KB'; $Exp = 1 }
    # Megabytes
    ElseIf (($Bytes -ge [math]::Pow(1024,2)) -and ($Bytes -lt [math]::Pow(1024,3))) { $Unit = 'MB'; $Exp = 2 }
    # Gigabytes
    ElseIf (($Bytes -ge [math]::Pow(1024,3)) -and ($Bytes -lt [math]::Pow(1024,4))) { $Unit = 'GB'; $Exp = 3 }
    # Terabytes and beyond
    ElseIf (($Bytes -ge [math]::Pow(1024,4))) { $Unit = 'TB'; $Exp = 4 }

    $Dividend = [math]::Pow(1024,$Exp)
    # Rounded to 2 significant digits
    $Quotient = [math]::Round(($Bytes / $Dividend), 2)

    Return "$Quotient $Unit"

}
     
# Get disk information
$Disks = Get-WmiObject -Class win32_logicaldisk -Filter "DriveType = 3" # 3 is local disk

# See if there are any disks above the specified threshold
$Results = New-Object Collections.ArrayList

# It doesn't matter how many disks there are - whether there's 1 or 20 - we'll
# look through all of them
ForEach ($Disk in $Disks) {
    $Size = $Disk.Size
    $Free = $Disk.FreeSpace
    $PercentFree = [math]::Round(($Free / $Size)*100, 1)
    $PercentUsed = (100 - $PercentFree)

    If ($PercentUsed -ge $PercentThreshold) {
        $Info = [PsCustomObject]@{
            DriveLetter = $Disk.DeviceID
            PercentUsed = "$($PercentUsed)%"
            Consumed    = Get-BytesUnit -Bytes "$($Size - $Free)"
            Available   = Get-BytesUnit $Free
            
        }

        $Results.Add($Info) | Out-Null
    }

}

If ($Results) {
    $Splat = @{
        SmtpServer = $SmtpServer
        From       = "no-reply@$env:userdnsdomain"
        To         = $Email
        Subject    = "CHECK STORAGE ON $env:ComputerName"
    }

    $Body = ($Results | ConvertTo-Html -Fragment | Out-String)
    Send-MailMessage @Splat -Body $Body -BodyAsHtml
}  
