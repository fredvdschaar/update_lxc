#!/usr/bin/env bash

# Copyright (c) 2021-2026 tteck
# Author: tteck (tteckster)
# Edit by: FvdS
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

### Functions
function info_line {
  echo -e "${BL}[info]${GN} $1 ${CL}\n"
}

function header_info() {
  cat <<"EOF"
   __  __          __      __          __   _  ________
  / / / /___  ____/ /___ _/ /____     / /  | |/ / ____/
 / / / / __ \/ __  / __ `/ __/ _ \   / /   |   / /
/ /_/ / /_/ / /_/ / /_/ / /_/  __/  / /___/   / /___
\____/ .___/\__,_/\__,_/\__/\___/  /_____/_/|_\____/
    /_/

EOF
  echo -e "${RD}===========[Adjusted version by FvdS]=================${CL}\n"
  info_line "Working on server $(hostname -f)"
}



info_line "Working on server $(hostname -f)"

# set colors
set -eEuo pipefail
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
CM='\xE2\x9C\x94\033'
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")

# set environment vars
SKIP_STOPPED="yes"
NODE=$(hostname)
excluded_containers=
containers_needing_reboot=()


# show the header
header_info
echo "Loading..."

function needs_reboot() {
  local container=$1
  local os=$(pct config "$container" | awk '/^ostype/ {print $2}')
  local reboot_required_file="/var/run/reboot-required.pkgs"
  if [ -f "$reboot_required_file" ]; then
    if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
      if pct exec "$container" -- [ -s "$reboot_required_file" ]; then
        return 0
      fi
    fi
  fi
  return 1
}

function update_container() {
  container=$1
  name=$(pct exec "$container" hostname)
  os=$(pct config "$container" | awk '/^ostype/ {print $2}')
  if [[ "$os" == "ubuntu" || "$os" == "debian" || "$os" == "fedora" ]]; then
    disk_info=$(pct exec "$container" df /boot | awk 'NR==2{gsub("%","",$5); printf "%s %.1fG %.1fG %.1fG", $5, $3/1024/1024, $2/1024/1024, $4/1024/1024 }')
    read -ra disk_info_array <<<"$disk_info"
    echo -e "${BL}[Info]${GN} Updating ${BL}$container${CL} : ${GN}$name${CL} - ${YW}Boot Disk: ${disk_info_array[0]}% full [${disk_info_array[1]}/${disk_info_array[2]} used, ${disk_info_array[3]} free]${CL}\n"
  else
    echo -e "${BL}[Info]${GN} Updating ${BL}$container${CL} : ${GN}$name${CL} - ${YW}[No disk info for ${os}]${CL}\n"
  fi
  case "$os" in
  alpine) pct exec "$container" -- ash -c "apk -U upgrade" ;;
  archlinux) pct exec "$container" -- bash -c "pacman -Syyu --noconfirm" ;;
  fedora | rocky | centos | alma) pct exec "$container" -- bash -c "dnf -y update && dnf -y upgrade" ;;
  ubuntu | debian | devuan) pct exec "$container" -- bash -c "apt-get update 2>/dev/null | grep 'packages.*upgraded'; apt list --upgradable 2>/dev/null | cat && apt-get -yq dist-upgrade 2>&1; rm -rf /usr/lib/python3.*/EXTERNALLY-MANAGED || true" ;;
  opensuse) pct exec "$container" -- bash -c "zypper ref && zypper --non-interactive dup" ;;
  esac
}


for container in $(pct list | awk '{if(NR>1) print $1}'); do
  if [[ " ${excluded_containers[@]} " =~ " $container " ]]; then
    header_info
    info_line "Skipping ${BL}$container"
    #echo -e "${BL}[Info]${GN} Skipping ${BL}$container${CL}"
    sleep 1
  else
    status=$(pct status $container)
    if [ "$SKIP_STOPPED" == "yes" ] && [ "$status" == "status: stopped" ]; then
      header_info
      info_line "Skipping ${BL}$container${CL}${GN} (not running)${CL}"
      #echo -e "${BL}[Info]${GN} Skipping ${BL}$container${CL}${GN} (not running)${CL}"
      sleep 1
      continue
    fi
    template=$(pct config $container | grep -q "template:" && echo "true" || echo "false")
    if [ "$template" == "false" ] && [ "$status" == "status: stopped" ]; then
      info_line "Starting${BL} $container"
      #echo -e "${BL}[Info]${GN} Starting${BL} $container ${CL} \n"
      pct start $container
      echo -e "${BL}[Info]${GN} Waiting For${BL} $container${CL}${GN} To Start ${CL} \n"
      sleep 5
      update_container $container
      info_line "Shutting down${BL} $container "
      #echo -e "${BL}[Info]${GN} Shutting down${BL} $container ${CL} \n"
      pct shutdown $container &
    elif [ "$status" == "status: running" ]; then
      update_container $container
    fi
    if [ "$status" == "status: running" ]; then
      if pct exec "$container" -- [ -e "/var/run/reboot-required" ]; then
        # Get the container's hostname and add it to the list
        container_hostname=$(pct exec "$container" hostname)
        containers_needing_reboot+=("$container ($container_hostname)")
      fi
      # check if patchmon agent is present in container and run a report if found
      if pct exec "$container" -- [ -e "/usr/local/bin/patchmon-agent" ]; then
        info_line "patchmon-agent found in ${BL} $container ${CL}, triggering report."
        #echo -e "${BL}[Info]${GN} patchmon-agent found in ${BL} $container ${CL}, triggering report. \n"
        pct exec "$container" -- "/usr/local/bin/patchmon-agent" "report"
      fi
    fi
  fi
  ## Run fstrim to shrink the container disk ##
  info_line "fstrim "$name
  #echo -e "${BL}[info]${GN} fstrim "$name
  echo -e "${CL}\n"
  pct fstrim "$container"
  echo -e "${RD}==============================================================${CL}\n"
  #echo -e "${CL}\n"
done

info_line "The process is complete, and the containers have been successfully updated."
#echo -e "${GN}The process is complete, and the containers have been successfully updated.${CL}\n"
if [ "${#containers_needing_reboot[@]}" -gt 0 ]; then
  echo -e "${RD}The following containers require a reboot:${CL}"
  for container_name in "${containers_needing_reboot[@]}"; do
    echo "$container_name"
  done
fi
echo ""
