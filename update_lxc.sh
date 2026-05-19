#!/usr/bin/env bash

# Copyright (c) 2021-2026 tteck
# Author: tteck (tteckster)
# Edit by: FvdS 2026-05-05
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

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

### Functions
function info_line() {
  echo -e "${BL}[info]${GN} $1 ${CL}\n"
}

function header_info() {
  echo -e "${GN}"
  cat <<"EOF"
   __  __          __      __          __   _  ________
  / / / /___  ____/ /___ _/ /____     / /  | |/ / ____/
 / / / / __ \/ __  / __ `/ __/ _ \   / /   |   / /
/ /_/ / /_/ / /_/ / /_/ / /_/  __/  / /___/   / /___
\____/ .___/\__,_/\__,_/\__/\___/  /_____/_/|_\____/
    /_/

EOF
  echo -e "${RD}===========[Adjusted version by FvdS]=================${CL}\n"
  info_line "Working on server [$(hostname -f)]"
}

# show the header
header_info
info_line "Loading..."

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
    info_line "Updating [${BL}$container${CL} : ${GN}$name${CL}] - ${YW}Boot Disk: ${disk_info_array[0]}% full [${disk_info_array[1]}/${disk_info_array[2]} used, ${disk_info_array[3]} free]"
    #echo -e "${BL}[Info]${GN} Updating [${BL}$container${CL} : ${GN}$name${CL}] - ${YW}Boot Disk: ${disk_info_array[0]}% full [${disk_info_array[1]}/${disk_info_array[2]} used, ${disk_info_array[3]} free]${CL}\n"
  else
    info_line "Updating [${BL}$container${CL} : ${GN}$name${CL}] - ${YW}[No disk info for ${os}]"
    #echo -e "${BL}[Info]${GN} Updating [${BL}$container${CL} : ${GN}$name${CL}] - ${YW}[No disk info for ${os}]${CL}\n"
  fi
  case "$os" in
    alpine) pct exec "$container" -- ash -c "apk -U upgrade" ;;
    archlinux) pct exec "$container" -- bash -c "pacman -Syyu --noconfirm" ;;
    fedora | rocky | centos | alma) pct exec "$container" -- bash -c "dnf -y update && dnf -y upgrade" ;;
    ubuntu | debian | devuan) pct exec "$container" -- bash -c "apt-get update 2>/dev/null | grep 'packages.*upgraded'; apt list --upgradable 2>/dev/null | cat && apt-get -yq dist-upgrade 2>&1; rm -rf /usr/lib/python3.*/EXTERNALLY-MANAGED || true" ;;
    opensuse) pct exec "$container" -- bash -c "zypper ref && zypper --non-interactive dup" ;;
  esac
}

# Clean the logfiles on the selected container
#
function run_lxc_clean() {
  local container=$1
  name=$(pct exec "$container" hostname)

  pct exec "$container" -- bash -c '
    BL="\033[36m"; GN="\033[1;92m"; CL="\033[m"
    name=$(hostname)
    if [ -e /etc/alpine-release ]; then
      echo -e "${BL}[Info]${GN} Cleaning logfiles of $name (Alpine) ${CL}\n"
      apk cache clean
      find /var/log -type f -delete 2>/dev/null
      find /tmp -mindepth 1 -delete 2>/dev/null
      #apk update
    elif [ -e /etc/redhat-release ]; then
      echo -e "${BL}[Info]${GN} Cleaning logfiles of $name (CentOS) ${CL}\n"
      yum clean all
      find /var/log -type f -delete 2>/dev/null
      find /tmp -mindepth 1 -delete 2>/dev/null
      yum update
      #yum upgrade -y
    else
      echo -e "${BL}[Info]${GN} Cleaning logfiles of $name (Debian/Ubuntu) ${CL}\n"
      find /var/cache -type f -delete 2>/dev/null
      find /var/log -type f -delete 2>/dev/null
      find /tmp -mindepth 1 -delete 2>/dev/null
      apt -y --purge autoremove
      apt -y autoclean
      rm -rf /var/lib/apt/lists/*
      #apt update
    fi
  '
}

#### 
# Main loop
####
num_container=$(pct list | awk '{if(NR>1) print $1}'|wc -w)
info_line "Updating $num_container LXC container(s)"

for container in $(pct list | awk '{if(NR>1) print $1}'); do
  ## clean up logfiles and packages
  run_lxc_clean "$container"
  ##
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
      sleep 1
      continue
    fi
    template=$(pct config $container | grep -q "template:" && echo "true" || echo "false")
    if [ "$template" == "false" ] && [ "$status" == "status: stopped" ]; then
      info_line "Starting${BL} $container"
      pct start $container
      #echo -e "${BL}[Info]${GN} Waiting For${BL} $container${CL}${GN} To Start ${CL} \n"
      info_line "Waiting For${BL} $container${CL}${GN} To Start"
      sleep 5
      update_container $container
      info_line "Shutting down${BL} $container "
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
        pct exec "$container" -- "/usr/local/bin/patchmon-agent" "report"
      fi
    fi
  fi
  ## Run fstrim to shrink the container disk ##
  info_line "fstrim "$name
  pct fstrim "$container"
  echo -e "${RD}==============================================================${CL}\n"
  #echo -e "${CL}n"
done

info_line "The process is complete and $num_container container(s) have been successfully updated."
if [ "${#containers_needing_reboot[@]}" -gt 0 ]; then
  echo -e "${RD}The following containers require a reboot:${CL}"
  for container_name in "${containers_needing_reboot[@]}"; do
    echo "$container_name"
  done
  # wait for keypress
  read -n 1 -s -r -p "Press any key to continue"
  echo ""
fi
echo ""
