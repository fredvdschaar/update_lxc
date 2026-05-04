# update_lxc
Script to update LXC's on Proxmox host called from ssh. Based on https://community-scripts.org/scripts/update-lxcs

## Adjusted
Adjusted because I want to run this "unattended" without any menu items to be selected. 

It assumes only running LXC containers will be updated. 

## Added:
I added the fstrim statement after each update.
