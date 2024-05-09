#!/bin/bash

#exit on error
set -e

#Create file for showing server logs
mkdir -p "${LOG_FILE%/*}" && touch "${LOG_FILE}"

# Start server through manager
echo "" > "${PID_FILE}"
manager start 

# Register SIGTERM handler to stop server gracefully
trap "manager stop --saveworld" SIGTERM

# On systemd notify service is ready
if [[ -n $NOTIFY_SOCKET ]] ; then
    systemd-notify --ready --status "Steam is ready..."
fi

# Start tail process in the background, then wait for tail to finish.
# This is just a hack to catch SIGTERM signals, tail does not forward
# the signals.
tail -F "${LOG_FILE}" &
wait $!

#sleep infinity #& wait
