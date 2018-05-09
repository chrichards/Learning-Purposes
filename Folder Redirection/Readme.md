Some information would need to be changed in this script if you wanted to run it in your own environment.
For it to work properly, it either needs to be:
  - Deployed as an application via ConfigMgr OR
  - Put on the selected system and run via psexec (psexec -s -e \\\computername cmd; powershell.exe [path])
Note: script has to be run as SYSTEM
