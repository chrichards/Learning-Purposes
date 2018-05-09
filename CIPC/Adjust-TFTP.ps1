# This script is for 32-bit CIPC
$OS_Bitness = (Get-WMIObject -class win32_OperatingSystem).OSArchitecture

If($OS_Bitness -eq "64-bit"){ $ciscodir = "HKLM:\SOFTWARE\Wow6432Node\Cisco Systems, Inc.\Communicator" }
Else{ $ciscodir = "HKLM:\SOFTWARE\Cisco Systems, Inc.\Communicator" }

Function Convert-to-Hex {
    Param($ipaddress)

    $conversiontable = @()
    $raw = $ipaddress.Split('.')
    For($i=0;$i -lt $raw.count;$i++){
        $octet = ([Convert]::ToString($raw[$i],16))
        If($octet.length -eq "1"){ $octet = $octet -replace "$octet","0$octet" }
        $conversiontable += $octet
    }
    # The hex output in the registry is actually backwards from the normal address
    $output = ($conversiontable[3] + $conversiontable[2] + $conversiontable[1] + $conversiontable[0])
    $output
}

$TFTP1 = Convert-to-Hex -ipaddress "[ip address here]"
$Value1 = [Convert]::ToInt32($TFTP1,16)
$TFTP2 = Convert-to-Hex -ipaddress "[ip address here]"
$Value2 = [Convert]::ToInt32($TFTP1,16)

If(Test-Path $ciscodir){
    $ciscoproperties = Get-ItemProperty -path $ciscodir
        If(!$ciscoproperties.AlternateTftp){
            New-ItemProperty -path $ciscodir -name "AlternateTftp" -PropertyType DWORD -Value "1" -Force
        }
        If(!$ciscoproperties.TftpServer1){
            New-ItemProperty -path $ciscodir -name "TftpServer1" -PropertyType DWORD -Value $Value1 -Force
        }
        If(!$ciscoproperties.TftpServer2){
            New-ItemProperty -path $ciscodir -name "TftpServer2" -PropertyType DWORD -Value $Value2 -Force
        }
}
