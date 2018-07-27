CLS
Write-Host "Please wait while the GPO report is generated..."

$Report = @()

$GPO_Names = Get-GPO -All | Select DisplayName | Sort DisplayName
$Total = $GPO_Names.Count
$i = 1

ForEach($Name in $GPO_Names){
    Write-Progress -Activity "Gathering GPO Info" -Status "$i of $Total Complete" -PercentComplete (100*($i/$Total)) 
    $GPO_XML = Get-GPOReport -Name $Name.DisplayName -ReportType XML
    $GPO = ([xml]$GPO_XML).GPO
    If(($GPO.LinksTo.SOMPath).Count -gt 1){
        For($a=0;$a -lt ($GPO.LinksTo.SOMPath).Count;$a++){
            If($a -ne 0){
                $Temp = New-Object PSObject
                $Temp | Add-Member -MemberType NoteProperty -Name "Name" -Value ""
                $Temp | Add-Member -MemberType NoteProperty -Name "Creation Date" -Value ""
                $Temp | Add-Member -MemberType NoteProperty -Name "Last Modified" -Value ""
                $Temp | Add-Member -MemberType NoteProperty -Name "Linked OU" -Value $GPO.LinksTo.SOMPath[$a]
                $Report += $Temp
            }
            Else{
                $Temp = New-Object PSObject
                $Temp | Add-Member -MemberType NoteProperty -Name "Name" -Value $GPO.Name
                $Temp | Add-Member -MemberType NoteProperty -Name "Creation Date" -Value $GPO.CreatedTime
                $Temp | Add-Member -MemberType NoteProperty -Name "Last Modified" -Value $GPO.ModifiedTime
                $Temp | Add-Member -MemberType NoteProperty -Name "Linked OU" -Value $GPO.LinksTo.SOMPath[$a]
                $Report += $Temp
            }
        }
    }
    Else{
        $Temp = New-Object PSObject
        $Temp | Add-Member -MemberType NoteProperty -Name "Name" -Value $GPO.Name
        $Temp | Add-Member -MemberType NoteProperty -Name "Creation Date" -Value $GPO.CreatedTime
        $Temp | Add-Member -MemberType NoteProperty -Name "Last Modified" -Value $GPO.ModifiedTime
        $Temp | Add-Member -MemberType NoteProperty -Name "Linked OU" -Value $GPO.LinksTo.SOMPath
        $Report += $Temp
    }
    $i++
}

$Report | Export-CSV "C:\users\chrisr\desktop\GPO-Result.csv" -NoTypeInformation 
