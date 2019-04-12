A GUI meant to guide a user through the iOS backup process while also compressing the backup and copying it to a centralized location.
This application requires iTunes and a 3rd party app called iMazing-CLI. 

Backup.ps1 uses PowerShell runspaces for optimal processing. It would probably be a lot more efficient to use a runspacepool,
but I couldn't figure out how to synchronize data between runspaces within the pool. Instead, I used multiple runspaces
as there would never be more than 2 running concurrently anyways.

The installer takes care of some nit-picky issues you'd run into when using the backup script. First and foremost, the purpose of this
utility was to allow a user to backup their device without ever having to interact with iTunes. The installer script ensures that iTunes
will not auto-launch when a device is plugged in by eliminating the iTunesHelper.exe file. It also adjusts an iTunes service, enabling
the user to stop/start the process (by way of copying the Windows service spooler's ACL). Finally, it creates a service using srvany.exe,
which can be found in the Windows NT 4.0 Resource Kit, to launch a required iTunes exe as 'SYSTEM'. 

As an aside for the backup script: there are bits where 'stop-process -id $PID' are called. It's not in any way, shape, or form the correct way of disposing of the app, but I couldn't figure out how to get the script to exit properly (since the script was wrapped up using PS2EXE, with some really nifty c# magic).
