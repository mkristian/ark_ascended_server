#!/bin/bash
set -e #uo pipefail

script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

all=$(ls -d1 -I  maps/* | sed 's/maps.//' | xargs echo)

if [[ -z $1 ]] ; then
  echo "usage: $0 <service name> [command]"
  echo "services: $(echo $all)"
  echo "no command defaults to show log file"
  exit 1
fi

if [[ $1 == 'update' ]] ; then
  for s in $all ; do
    echo "---"
    echo "Stopping $s"
    echo "---"
    podman exec -t $s manager stop
  done
  echo "---"
  echo "Updating application via steamcmd"
  podman exec -t steamcmd /opt/steam.sh update
  for s in $all ; do
    echo "---"
    echo "Starting $s"
    echo "---"
    podman exec -t $s manager start
  done
  exit 0
fi

container=$1
shift

# Short-circuit the logs command since we don't want to run it through the container's manager binary
if [[ -z "$1" ]] ; then
  podman exec -t $container cat manager.log
  exit 0
fi

podman exec -it $container manager "${@}"
