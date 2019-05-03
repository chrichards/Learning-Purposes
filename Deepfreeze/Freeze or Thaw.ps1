Param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Freeze","Thaw")]
    [ValidateNotNull()]
    [string]$SetState,
    [Parameter(Mandatory=$true)]
    [ValidateNotNull()]
    [string]$Password
)

If(Test-Path "$env:windir\SysWOW64\DFC.exe"){ $DFC = "$env:windir\SysWOW64\DFC.exe" }
ElseIf(Test-Path "$env:windir\System32\DFC.exe"){ $DFC = "$env:windir\System32\DFC.exe" }
Else{
    write-output "No Deepfreeze"
}

if($DFC){
    $state = Start $DFC -ArgumentList "get /ISFROZEN" -Wait -PassThru
    If($state.ExitCode -notin (0..1)){[System.Environment]::Exit(1)}

    If($SetState -eq "Freeze"){
        If($state.ExitCode -eq 1){
            $restart = $false 
        }
        Else{
            Start $DFC -ArgumentList "$Password /FREEZENEXTBOOT" -Wait
            $restart = $true
        }
    }
    If($SetState -eq "Thaw"){
        If($state.ExitCode -eq 0){
            $restart = $false
        }
        Else{
            Start $DFC -ArgumentList "$Password /THAWNEXTBOOT" -Wait
            $restart = $true
        }
    }

    If($restart -eq $true){
        write-output "Set"
    }
    Else{
        write-output "Error"
    }
}
