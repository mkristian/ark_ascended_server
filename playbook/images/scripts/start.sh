#!/bin/bash

#exit on error
set -e

LOG=/opt/arkserver/ShooterGame/Saved/Logs/ShooterGame.log

#Create file for showing server logs
mkdir -p "${LOG%/*}" && touch "${LOG}"

# Start server through manager
manager resume

# Register SIGTERM handler to stop server gracefully
trap "manager halt --saveworld" SIGTERM

# On systemd notify service is ready
if [[ -n $NOTIFY_SOCKET ]] ; then
    systemd-notify --ready --status "Steam is ready..."
fi

# Start tail process in the background, then wait for tail to finish.
# This is just a hack to catch SIGTERM signals, tail does not forward
# the signals.
tail -n 0 -F "${LOG}" | sed -e "s/^/\x1B[0;1;34m$CLUSTER_ID \x1B[0;1;33m$MAP_NAME\x1B[0m\ /" &
wait $!
