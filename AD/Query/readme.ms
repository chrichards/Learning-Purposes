1) user-logon-activity.ps1 was written for a friend's large AD environment to help speed up reporting. Tested in my environment 
   with just a little over 22k users, the report was generated in about 13 seconds. This script is handy for environments larger than
   10k objects and can easily be outfitted to look for different attributes, objects, etc. Forewarning: you may want to adjust the
   runspace pool maximum concurrent thread count (currently set to 10) as it can tax your CPU pretty heavily.
