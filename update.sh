#!/bin/bash
clear

 _   _           _       _         ____  ____  _______        __
| | | |_ __   __| | __ _| |_ ___  | __ )|  _ \| ____\ \      / /
| | | | '_ \ / _` |/ _` | __/ _ \ |  _ \| |_) |  _|  \ \ /\ / /
| |_| | |_) | (_| | (_| | ||  __/ | |_) |  _ <| |___  \ V  V /
 \___/| .__/ \__,_|\__,_|\__\___| |____/|_| \_\_____|  \_/\_/
      |_|

      
# show the last time this script ran
if test -f ~/update.dat; then
  echo Last run:
  cat ~/update.dat
fi
echo $(date) > ~/update.dat


# Brew
brew outdated&&brew upgrade&&brew cleanup
exit 1

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
