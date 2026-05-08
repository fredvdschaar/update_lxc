#!/bin/bash
clear

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
 _   _           _       _         ____  ____  _______        __
| | | |_ __   __| | __ _| |_ ___  | __ )|  _ \| ____\ \      / /
| | | | '_ \ / _` |/ _` | __/ _ \ |  _ \| |_) |  _|  \ \ /\ / /
| |_| | |_) | (_| | (_| | ||  __/ | |_) |  _ <| |___  \ V  V /
 \___/| .__/ \__,_|\__,_|\__\___| |____/|_| \_\_____|  \_/\_/
      |_|

EOF
  info_line "Updating BREW on [$(hostname -f)]"
}

header_info

      
# show the last time this script ran
if test -f ~/update.dat; then
  echo Last run:
  cat ~/update.dat
fi
echo $(date) > ~/update.dat


# Brew
brew outdated&&brew upgrade&&brew cleanup
echo -e All brews updated
