If(Test-Path "$env:windir\SysWOW64\DFC.exe"){ $DFC = "$env:windir\SysWOW64\DFC.exe" }
ElseIf(Test-Path "$env:windir\System32\DFC.exe"){ $DFC = "$env:windir\System32\DFC.exe" }
Else{
    write-output "No Deepfreeze"
    [System.Environment]::Exit(1)
}

$state = Start $DFC -ArgumentList "get /ISFROZEN" -Wait -PassThru
If($state.ExitCode -notin (0..1)){[System.Environment]::Exit(1)}
Else{
    If($state.ExitCode -eq 0){
        write-output "Thawed"
    }
    If($state.ExitCode -eq 1){
        write-output "Frozen"
    }
}
