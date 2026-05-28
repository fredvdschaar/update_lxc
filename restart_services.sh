#!/bin/bash
# Restart all systemd services that have status 'running'
systemctl list-units --type=service  --no-pager --no-legend --full \
    | grep -Po '^\S+(?=\s+loaded\s+active running)' \
    | (while read var1 ; do
            strservices+=" ${var1}"
        done
        #restart in one transaction to let systemctl handle dependencies
        systemctl restart $strservices
    )


#####
active_service='$(curl -fsSL https://raw.githubusercontent.com/fredvdschaar/update_lxc/refs/heads/main/services.dat)'
echo $active_service|grep $(hostname)
for service in $(systemctl list-units --type=service  --no-pager --no-legend --full | grep running | awk NF=1); do

