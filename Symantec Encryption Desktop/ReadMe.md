If you work with the full-disk encryption solution 'Symantec Encryption Desktop' (formerly known as PGP),
you know that the BootGuard can get in the way of maintenance tasks. This scripts helps admins create 
BootGuard bypasses to enable computers to successfully reboot without impediment. 

While this file can easily be used locally, you can also use it with SCCM. 
   - Deployed as a script
   - Deployed as a package
     - In the Command section for the program, use: 
     powershell.exe -Command "& .\[what you named the script].ps1 -Action [Add|Check|Remove]
     -Count [n] -AdminPass [WDE Administrator Password]"
     - 'Count' is only used in conjunction with 'Add'
