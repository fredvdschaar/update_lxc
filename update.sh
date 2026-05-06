#!/bin/bash
clear

# show the last time this script ran
if test -f ~/update.dat; then
  echo Last run:
  cat ~/update.dat
fi
echo $(date) > ~/update.dat


# Brew
brew outdated&&brew upgrade&&brew cleanup

user=root
gituser=fredvdschaar

# proxmox
clear
for hostName in proxmox.local pve02.local ;
  do
    clear
    ssh $user@$hostName 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/$gituser/update_lxc/refs/heads/main/update_lxc.sh)"'

  done

echo -e All proxmox hosts updated
