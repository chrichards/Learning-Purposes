# Get list of all programs installed on the computer
$Installed_Programs = Get-WMIObject -class win32_Product
$Old_Office = $null

# Check for Office 2013
# This determines if an upgrade is necessary
If($Installed_Programs | Where{$_.Name -eq "Microsoft Office Professional Plus 2013"}){ $Old_Office = $true }
Else{ Exit 0 }

# Function for building uninstall XMLs
Function Define-Product {
Param ([string]$Product_ID)

$Uninstall_XML = @"
<Configuration Product="$Product_ID">

<Display Level="basic" CompletionNotice="no" SuppressModal="yes" AcceptEula="yes" />

<Setting Id="SETUP_REBOOT" Value="Never" />

</Configuration>
"@

$script:Uninstall_XML = $Uninstall_XML
}

# Define Office habitation variables
$Office_2010 = "C:\Program Files\Common Files\Microsoft Shared\OFFICE14\Office Setup Controller"
$Office_2010_x86 = "C:\Program Files (x86)\Common Files\Microsoft Shared\OFFICE14\Office Setup Controller"
$Office_2013 = "C:\Program Files\Common Files\Microsoft Shared\OFFICE15\Office Setup Controller"
$Office_2013_x86 = "C:\Program Files (x86)\Common Files\Microsoft Shared\OFFICE15\Office Setup Controller"
$Office_2016 = "C:\Program Files\Common Files\Microsoft Shared\OFFICE16\Office Setup Controller"
$Office_2016_x86 = "C:\Program Files (x86)\Common Files\Microsoft Shared\OFFICE16\Office Setup Controller"

# Make ConfigMgr TS Variable COM Object
$TS_Variable = New-Object -COMObject Microsoft.SMS.TSEnvironment

# Define Working Directory
$Working_Directory = Get-Location

# Begin main script
If($Old_Office -eq $true){
    ForEach($Program in $Installed_Programs){
        If($Program.Name -eq "Microsoft Junk E-mail Reporting Add-in"){
            Write-Host "Uninstalling " $Program.Name
            $ID = $Program.IdentifyingNumber
            Start-Process msiexec.exe -ArgumentList "/x $ID /qn" -Wait -NoNewWindow
        }

        If($Program.Name -eq "Microsoft Visio Viewer 2010"){
            Write-Host "Uninstalling " $Program.Name
            $ID = $Program.IdentifyingNumber
            Start-Process msiexec.exe -ArgumentList "/x $ID /qn" -Wait -NoNewWindow
        }

        If($Program.Name -eq "Microsoft Office Visio 2010"){
            Write-Host "Uninstalling" $Program.Name
            Define-Product -Product_ID "Visio"
            If(Test-Path "$Office_2010\VISIO"){
                $Uninstall_XML | Out-File "$Office_2010\VISIO\VisUninstall.xml"
                CD $Office_2010
                Start-Process .\setup.exe -ArgumentList {/uninstall Visio /config ".\VISIO\VisUninstall.xml"} -Wait -NoNewWindow
            }
            Else{
                $Uninstall_XML | Out-File "$Office_2010_x86\VISIO\VisUninstall.xml"
                CD $Office_2010_x86
                Start-Process .\setup.exe -ArgumentList {/uninstall Visio /config ".\VISIO\VisUninstall.xml"} -Wait -NoNewWindow
            }
            $TS_Variable.Value("NeedVisio") = "True"
        }

        If($Program.Name -eq "Microsoft Visio Professional 2010"){
            Write-Host "Uninstalling" $Program.Name
            Define-Product -Product_ID "Visio"
            If(Test-Path "$Office_2010\VISIO"){
                $Uninstall_XML | Out-File "$Office_2010\VISIO\VisUninstall.xml"
                CD $Office_2010
                Start-Process .\setup.exe -ArgumentList {/uninstall Visio /config ".\VISIO\VisUninstall.xml"} -Wait -NoNewWindow
            }
            Else{
                $Uninstall_XML | Out-File "$Office_2010_x86\VISIO\VisUninstall.xml"
                CD $Office_2010_x86
                Start-Process .\setup.exe -ArgumentList {/uninstall Visio /config ".\VISIO\VisUninstall.xml"} -Wait -NoNewWindow
            }
            $TS_Variable.Value("NeedVisio") = "True"
        }

        If($Program.Name -eq "Microsoft Visio Premium 2010"){
            Write-Host "Uninstalling" $Program.Name
            Define-Product -Product_ID "Visio"
            If(Test-Path "$Office_2010\VISIO"){
                $Uninstall_XML | Out-File "$Office_2010\VISIO\VisUninstall.xml"
                CD $Office_2010
                Start-Process .\setup.exe -ArgumentList {/uninstall Visio /config ".\VISIO\VisUninstall.xml"} -Wait -NoNewWindow
            }
            Else{
                $Uninstall_XML | Out-File "$Office_2010_x86\VISIO\VisUninstall.xml"
                CD $Office_2010_x86
                Start-Process .\setup.exe -ArgumentList {/uninstall Visio /config ".\VISIO\VisUninstall.xml"} -Wait -NoNewWindow
            }
            $TS_Variable.Value("NeedVisio") = "True"
        }

        If($Program.Name -eq "Microsoft Project Standard 2010"){
            Write-Host "Uninstalling" $Program.Name
            Define-Product -Product_ID "PrjStd"
            If(Test-Path "$Office_2010\PRJSTD"){
                $Uninstall_XML | Out-File "$Office_2010\PRJSTD\PrjStdUninstall.xml"
                CD $Office_2010
                Start-Process .\setup.exe -ArgumentList {/uninstall PrjStd /config ".\PRJSTD\PrjStdUninstall.xml"} -Wait -NoNewWindow
            }
            Else{
                $Uninstall_XML | Out-File "$Office_2010_x86\PRJSTD\PrjStdUninstall.xml"
                CD $Office_2010_x86
                Start-Process .\setup.exe -ArgumentList {/uninstall PrjStd /config ".\PRJSTD\PrjStdUninstall.xml"} -Wait -NoNewWindow
            }
            $TS_Variable.Value("NeedProject") = "True"
        }

        If($Program.Name -eq "Microsoft Project Professional 2010"){
            Write-Host "Uninstalling" $Program.Name
            Define-Product -Product_ID "PrjPro"
            If(Test-Path "$Office_2010\PRJPRO"){
                $Uninstall_XML | Out-File "$Office_2010\PRJPRO\PrjProUninstall.xml"
                CD $Office_2010
                Start-Process .\setup.exe -ArgumentList {/uninstall PrjPro /config ".\PRJPRO\PrjProUninstall.xml"} -Wait -NoNewWindow
            }
            Else{
                $Uninstall_XML | Out-File "$Office_2010_x86\PRJPRO\PrjProUninstall.xml"
                CD $Office_2010_x86
                Start-Process .\setup.exe -ArgumentList {/uninstall PrjPro /config ".\PRJPRO\PrjProUninstall.xml"} -Wait -NoNewWindow
            }
            $TS_Variable.Value("NeedProject") = "True"
        }

        If($Program.Name -eq "Microsoft Office Professional Plus 2010"){
            Write-Host "Uninstalling" $Program.Name
            Define-Product -Product_ID "ProPlus"
            If(Test-Path "$Office_2010\setup.exe"){
                $Uninstall_XML | Out-File "$Office_2010\PROPLUS\BasicUninstall.xml"
                CD $Office_2010
                Start-Process .\setup.exe -ArgumentList {/uninstall ProPlus /config ".\PROPLUS\BasicUninstall.xml"} -Wait -NoNewWindow
            }
            Else{
                $Uninstall_XML | Out-File "$Office_2010_x86\PROPLUS\BasicUninstall.xml"
                CD $Office_2010_x86
                Start-Process .\setup.exe -ArgumentList {/uninstall ProPlus /config ".\PROPLUS\BasicUninstall.xml"} -Wait -NoNewWindow
            }
            $TS_Variable.Value("NeedOffice") = "True"
        }

        If($Program.Name -eq "Microsoft Visio Standard 2013"){
            Write-Host "Uninstalling" $Program.Name
            Define-Product -Product_ID "VisStd"
            If(Test-Path "$Office_2013\VISIO"){
                $Uninstall_XML | Out-File "$Office_2013\VISIO\VisStdUninstall.xml"
                CD $Office_2013
                Start-Process .\setup.exe -ArgumentList {/uninstall VisStd /config ".\VISIO\VisStdUninstall.xml"} -Wait -NoNewWindow
            }
            Else{
                $Uninstall_XML | Out-File "$Office_2013_x86\VISIO\VisStdUninstall.xml"
                CD $Office_2013_x86
                Start-Process .\setup.exe -ArgumentList {/uninstall VisStd /config ".\VISIO\VisStdUninstall.xml"} -Wait -NoNewWindow
            }
            $TS_Variable.Value("NeedVisio") = "True"
        }

        If($Program.Name -eq "Microsoft Visio Professional 2013"){
            Write-Host "Uninstalling" $Program.Name
            Define-Product -Product_ID "VisPro"
            If(Test-Path "$Office_2013\VISIO"){
                $Uninstall_XML | Out-File "$Office_2013\VISIO\VisProUninstall.xml"
                CD $Office_2013
                Start-Process .\setup.exe -ArgumentList {/uninstall VisPro /config ".\VISIO\VisProUninstall.xml"} -Wait -NoNewWindow
            }
            Else{
                $Uninstall_XML | Out-File "$Office_2013_x86\VISIO\VisProUninstall.xml"
                CD $Office_2013_x86
                Start-Process .\setup.exe -ArgumentList {/uninstall VisPro /config ".\VISIO\VisProUninstall.xml"} -Wait -NoNewWindow
            }
            $TS_Variable.Value("NeedVisio") = "True"
        }

        If($Program.Name -eq "Microsoft Project Professional 2013"){
            Write-Host "Uninstalling" $Program.Name
            Define-Product -Product_ID "PrjPro"
            If(Test-Path "$Office_2013\PRJPRO"){
                $Uninstall_XML | Out-File "$Office_2013\PRJPRO\PrjProUninstall.xml"
                CD $Office_2013
                Start-Process .\setup.exe -ArgumentList {/uninstall PrjPro /config ".\PRJPRO\PrjProUninstall.xml"} -Wait -NoNewWindow
            }
            Else{
                $Uninstall_XML | Out-File "$Office_2013_x86\PRJPRO\PrjProUninstall.xml"
                CD $Office_2013_x86
                Start-Process .\setup.exe -ArgumentList {/uninstall PrjPro /config ".\PRJPRO\PrjProUninstall.xml"} -Wait -NoNewWindow
            }
            $TS_Variable.Value("NeedProject") = "True"
        }

        If($Program.Name -eq "Microsoft Office Professional Plus 2013"){
            Write-Host "Uninstalling" $Program.Name
            Define-Product -Product_ID "ProPlus"
            If(Test-Path "$Office_2013\ProPlus"){
                $Uninstall_XML | Out-File "$Office_2013\ProPlus\BasicUninstall.xml"
                CD $Office_2013
                Start-Process .\setup.exe -ArgumentList {/uninstall ProPlus /config ".\ProPlus\BasicUninstall.xml"} -Wait -NoNewWindow
            }
            Else{
                $Uninstall_XML | Out-File "$Office_2013_x86\ProPlus\BasicUninstall.xml"
                CD $Office_2013_x86
                Start-Process .\setup.exe -ArgumentList {/uninstall ProPlus /config ".\ProPlus\BasicUninstall.xml"} -Wait -NoNewWindow
            }
            $TS_Variable.Value("NeedOffice") = "True"
            $Removed_Office_2013 = $true
        }

        If($Program.Name -eq "Microsoft Office Professional Plus 2016"){
            Write-Host "Uninstalling" $Program.Name
            Define-Product -Product_ID "ProPlus"
            If(Test-Path "$Office_2016\ProPlus"){
                $Uninstall_XML | Out-File "$Office_2016\ProPlus\BasicUninstall.xml"
                CD $Office_2016
                Start-Process .\setup.exe -ArgumentList {/uninstall ProPlus /config ".\ProPlus\BasicUninstall.xml"} -Wait -NoNewWindow
            }
            Else{
                $Uninstall_XML | Out-File "$Office_2016_x86\ProPlus\BasicUninstall.xml"
                CD $Office_2016_x86
                Start-Process .\setup.exe -ArgumentList {/uninstall ProPlus /config ".\ProPlus\BasicUninstall.xml"} -Wait -NoNewWindow
            }
            $TS_Variable.Value("NeedOffice") = "True"
        }
    }
}

If($Removed_Office_2013 -eq $true){ Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office 2013" -Recurse -Force }
If(Test-Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office"){ Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office" -Recurse -Force }
