1) List-Apps.ps1 is a quick and handy script for yanking out what's installed on a machine, versions, and what's presented
as the uninstall string. If a 'QuietUninstall' is present, that's what the function will return as the uninstall string. It also
includes the ability to check out LOADED users and what they have installed. Could it have loaded up each user hive on a machine 
and iterate through those, too? Sure. But this was in an effort to be fast and efficient.
