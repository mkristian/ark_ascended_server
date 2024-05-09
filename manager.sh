#!/bin/bash
set -e #uo pipefail

script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

all=$(podman ps | grep asa_ | sed s/.*asa_/asa_/)

if [[ -z $1 ]] ; then
  echo "usage: $0 <service name> [command]"
  echo "services: $(echo $all)"
  echo "no command defaults to show log file"
  exit 1
fi

container=$1
shift

# Short-circuit the logs command since we don't want to run it through the container's manager binary
if [[ -z "$1" ]] ; then
  podman exec -t $container cat manager.log
  exit 0
fi

podman exec -t $container manager "${@}"
