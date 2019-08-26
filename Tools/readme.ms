1) List-Apps.ps1 is a quick and handy script for yanking out what's installed on a machine, versions, and what's presented
as the uninstall string. If a 'QuietUninstall' is present, that's what the function will return as the uninstall string. It also
includes the ability to check out LOADED users and what they have installed. Could it have loaded up each user hive on a machine 
and iterate through those, too? Sure. But this was in an effort to be fast and efficient.

2) old-profile.ps1 isn't anything too spectacular. You run this script on a local computer and remove old profiles that haven't logged
in with whatever amount of days you specify. It only looks at network accounts so local accounts AND system accounts are ignored. It's
a best-effort script, meaning it might fail trying to remove the local userprofile that is already built.
