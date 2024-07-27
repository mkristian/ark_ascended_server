#!/bin/bash
set -e #uo pipefail

script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

if [[ -z $2 ]] ; then
  maps=$(ls -d1 -I  maps/* | sed 's/maps.//' | xargs echo)
else
  maps=$1
  shift
fi

manager() {
  local map=$1
  shift
  podman exec -t $map manager $@
}

all_services() {
  local action=$1
  shift
  for map in $maps ; do
    
    echo "--- $action $map"
    for cmd in $@ ; do
      systemctl --user $cmd $map --no-pager
    done
    echo
  done
}

all_pods() {
  local action=$1
  shift
  for map in $maps ; do
    
    echo "--- $action $map"

    manager $map $@
    echo
  done
}

if [[ -z $1 ]] ; then
  echo "usage: $0 <service name> [command]"
  echo "services: $(echo $all)"
  echo "no command defaults to show log file"
  exit 1
fi

case $1 in

  backup)
    all_pods Backup backup
    exit 0
    ;;

  update)
    all_pods Halting halt
    podman exec -t steamcmd /opt/steam.sh update
    echo
    all_pods Resuming resume
    all_pods Status status 
    exit 0
    ;;

  status)
    all_pods Status status --full
    exit 0
    ;;

  reconfigure)
    all_services "Restarting service" restart status
    exit 0
    ;;

  start)
    all_pods "Starting" start
    exit 0
    ;;

  stop)
    all_pods "Stopping" stop
    exit 0
    ;;

  log)
    #podman exec -t $container cat manager.log
    echo "TODO: logs"
    exit 0
    ;;

  *)
    echo "usage: $0 [map] command"
    cmds=$(grep '^[ a-z]*)$' $0 | sed 's/)//g' | xargs echo)
    echo "       commands: $(echo $cmds | sed s/\ /,\ /g)"
    echo "       maps    : $(echo $maps | sed s/\ /,\ /g)"
    [[ $1 == 'help' ]]
    exit $?
    ;;

esac
exit


podman exec -it $container manager "${@}"
