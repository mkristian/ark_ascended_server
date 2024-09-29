#!/bin/bash

#set -euo pipefail

_B="\033[0;1;30m"
_R="\033[0;1;31m"
_G="\033[0;1;32m"
_Y="\033[0;1;33m"
_B="\033[0;1;34m"
_P="\033[0;1;35m"
_C="\033[0;1;36m"
_W="\033[0;1;37m"
__="\033[0m"

scriptdir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
basedir=$(realpath "$scriptdir/..")
mapsdir="$basedir/maps"

map() {
  if [[ -z $1 ]]
  then
    echo "usage: $0 $cmd <map name>"
    exit 123
  fi
  local map=$1
  if [[ ! -f "$mapsdir/$map/env" ]]
  then
    echo -e "$_R$mapsdir/$map/env$__ does not exists"
    echo "usage: $0 $cmd <map name>"
    exit 123
  fi
  local path="$basedir/ark_backup/${CLUSTER_ID}/$map"
  mkdir -p $path
  clusterflag="$path/cluster"
}

manager() {
  local map=$1
  local cmd=$2
  echo -e "${cmd/s/S} $_Y$map$__ cluster $_B$CLUSTER_ID$__"
  podman exec -t $map manager $cmd
}

source "$mapsdir/env"
all=$(ls -d1 maps/* | grep -v env | sed 's/maps.//' | xargs echo)
cmd=$1
shift

for_all_maps() {
  local cmd=$1
  for map in $all
  do
    map $map
    if [[ -f $clusterflag ]]
    then
      case $cmd in
        start|status|stop)
          manager $map $cmd &
          ;;
        show)
          echo -e "Part of $_Y$map$__ cluster $_B$CLUSTER_ID$__"
          ;;
      esac
    else
      echo -e "${__}Skip $_Y$map$__ - not part of the cluster $_B$CLUSTER_ID$__" 
    fi
  done
  wait
}

cmdlist_wo_args() {
  grep ")" $0 | grep -v "(" | grep "      " | sed "s/[|)]/ /g" | xargs echo | sed -e "s/\ /|/g"
}

cmdlist_spc() {
  grep cmd\ == $0 | sed -e "s/[^']*'//" -e "s/'.*//" | xargs echo | sed -e "s/\ /|/g"
}

cmdlist_w_args() {
  grep ")" $0 | grep -v "(" | grep -v "      " | sed "s/[|)]/ /g" | xargs echo | sed -e "s/\ /|/g"
}

all_services() {
  local cmd=$1
  for map in $all; do
    echo -e "$cmd $_Y$map$__ cluster $_B$CLUSTER_ID$__"
    systemctl --user $cmd $map --no-pager &
  done
  wait
}

if [[ -z $cmd ]]
then
  echo "usage: $0 [$(cmdlist_spc)|$(cmdlist_wo_args)] [{$(cmdlist_w_args)} {${all// /|}}]"
  exit
fi
if [[ -z $1 ]]
then
  if [[ $cmd == 'update' ]]
  then
    for_all_maps stop
    podman exec -t steamcmd /opt/steam.sh update
    echo
    for_all_maps start 
  elif [[ $cmd == 'reconfigure' ]]
  then
	  echo asd
    all_services restart
	  echo asd
    all_services status
  else
    for_all_maps $cmd
  fi
else
  map=$1
  shift
  case $cmd in
    add)
      map "$map"
      if [[ -f "$clusterflag" ]]
      then
        echo -e "$_Y$map$__ is already part of the cluster $_B$CLUSTER_ID$__"
        exit
      fi
      touch $clusterflag
      echo -e "added $_Y$map$__ to cluster $_B$CLUSTER_ID$__"
      manager $map start
      ;;

    remove)
      map "$map"
      if [[ ! -f "$clusterflag" ]]
      then
        echo -e "$_Y$map$__ is already gone from cluster $_B$CLUSTER_ID$__"
        exit
      fi
      rm $clusterflag
      echo -e "removed $_Y$map$__ from cluster $_B$CLUSTER_ID$__"
      manager $map stop
      ;;
    saveworld)
      manager $map saveworld
      ;;
  esac
fi
