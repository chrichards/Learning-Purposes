#!/bin/bash
# Before you run this, make sure to make a key
# I typically run something like:
# arr=(); for ((i=0;i<256;i++)); do; arr+=$(jot -r 1 0 255); done; echo "${arr[@]}"
# I will then take that big ol' byte array and deploy it as a separate script to /var/tmp/[name of file]

# The plaintext passwords will then need to be encrypted using:
# echo "plaintext password" | openssl enc -k "$(key you made above)" -aes256 -base64 -e
# Yes, I'm aware it's not a key and is in fact a password...

# Can adjust this later but this is just for ease of use with Jamf
user=$4
oldpwd=$5
newpwd=$6
org='[whatever your org is]'
logo='[put in a nice base64 encoded image here]'
remove_acct="FALSE"

# First, let's get some barriers out of the way and
# make sure that whatever password you have won't get blocked
pwpolicy clearaccountpolicies

# User creation function
NewUser () { 
	user=$1
	icon=$2
	pass=$3
	# find the next available ID
	n=501
	while [[ $(dscl . list /Users UniqueID | grep $n) ]]; do 
		((n++))
	done
	
	# create the admin account
	dscl . create /Users/$user
	dscl . create /Users/$user RealName "$user"
	dscl . create /Users/$user picture "$icon"
	dscl . append /Users/$user AuthenticationAuthority ";DisabledTags;SecureToken"
	dscl . passwd /Users/$user "$pass"
	dscl . create /Users/$user UniqueID $n
	dscl . create /Users/$user PrimaryGroupID 80
	dscl . create /Users/$user UserShell /bin/zsh
	dscl . create /Users/$user NFSHomeDirectory /Users/$user
	createhomedir -u $user
} 

# Does the user icon exist? If not, put it there
if [[ ! -d "/Library/User Pictures/$org" ]]; then
	echo "User icon doesn't exist - creating it."
	mkdir "/Library/User Pictures/$org"
fi

if [[ ! -f "/Library/User Pictures/$org/logo.png" ]]; then
	icon="/Library/User Pictures/$org/logo.png"
	echo "$logo" | base64 -d > "$icon"
fi

# Redeclare variables
newpwd=$(echo -e "$newpwd" | openssl enc -k "$(cat /var/tmp/array)" -aes256 -base64 -d)
oldpwd=$(echo -e "$oldpwd" | openssl enc -k "$(cat /var/tmp/array)" -aes256 -base64 -d)

# If the account doesn't exist, make it
if [[ ! $(dscl . -list /Users | grep -wi $user) ]]; then # grep is a case insensitive exact match i.e. match jsmith or JSmith but not jsmith1
	echo "Admin accout doesn't exist - creating $user."
	NewUser "$user" "$icon" "$newpwd"
else	# The account exists!
	echo "Admin account exists."
	echo "Checking account password status."
	pass_check=$(dscl . authonly $user $oldpwd &> /dev/null; echo $?)
	
	if [ "$pass_check" -eq 0 ]; then
		# we can change the password! hooray!
		echo "Changing the password for $user."
		dscl . -passwd /Users/$user $oldpwd $newpwd
		
		# just double check that the new pass was implemented
		# yes, you could just do $? on the pass change but this feels more direct
		pass_check=$(dscl . authonly $user $newpwd &> /dev/null; echo $?)
		
		if [ "$pass_check" -eq 0 ]; then
			echo "New password was set successfully!"
			exit 0
		else
			echo "Couldn't set new password."
			remove_acct="TRUE"
		fi
	else
		# we're unable to change the password because we don't know the current password
		echo "Cannot change current password."
		remove_acct="TRUE"
	fi
fi

if [[ "$remove_acct" == "TRUE" ]]; then
	# we'll try to delete the account and re-create it
	# first, we have to look and see if the account has a secure token
	echo "Attempting to delete the account."
	
	if [[ $(sysadminctl -secureTokenStatus $user 2>&1) =~ "ENABLED" ]]; then
		# bad luck, the account has a secure token 
		echo "Account has a secureToken - cannot remove."
	else
		dscl . -delete /Users/$user
		check=$(dscl . -list /Users | grep -wi $user)
		
		if [ -z $check ]; then
			echo "Account was successfully deleted!"
		else
			echo "Unable to remove account - please check system manually."
			exit 1
		fi
		
		echo "Creating new account with new password."
		NewUser "$user" "$icon" "$newpwd"
		
		check=$(dscl . -list /Users | grep -wi $user)
		
		if [ -n $check ]; then
			echo "Account was successfully created!"
		else
			echo "Unable to create account - please check system manually."
			exit 1
		fi
	fi
fi

