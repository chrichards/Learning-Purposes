The beginning of a strange project...

The purpose of these scripts is to have a single machine with some scheduled jobs wake all of the machines in its respective subnet.
Eventually, a GUI will be made to enable a user to wake machines on-demand/have a dashboard telling them which machines are in the
subnet and their network status.

wol.ps1
This is the actual wake-on-lan script. This script accepts MAC address parameters and attempts to send a "magic packet" to wake up
a sleeping/powered-off system. Depending on what type of system/OEM, there are varying levels of how the system can be powered on through
the use of a "magic packet."

subnet-gather.ps1
This script will calculate what subnet the host is in, how many hosts are in the subnet, and then query DNS to find out all of the
computers associated with said subnet.

mac-gather.ps1
Using the information generated with subnet-gather, the script host will then attempt to contact all of the computers available to it.
If the computer is reachable, the script will begin creating a "database" of the computername and its respective MAC address. These
MAC addresses would then be fed into wol.ps1
