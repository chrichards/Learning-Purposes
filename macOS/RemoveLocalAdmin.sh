#!/bin/bash
ignore=$4
localAccounts=$(dscl . list /Users UniqueID | awk '$2>502{print $1}' | grep -v $ignore)

for account in "$localAccounts"
do
  if [[ $(dscacheutil -q group -a name admin | grep $account) ]]
  then
    echo "Removing $account from admin group"
    dseditgroup -o edit -d $account admin
  fi
done
