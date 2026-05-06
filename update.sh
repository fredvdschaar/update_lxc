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

# proxmox
clear
ssh root@proxmox.local 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/fredvdschaar/update_lxc/refs/heads/main/update_lxc.sh)"'

#pve02
clear
ssh root@pve02.local 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/fredvdschaar/update_lxc/refs/heads/main/update_lxc.sh)"'

# docker host
#ssh fred@pi-stijn "./update.sh"
fred@Luke-Skywalker ~ %
