#!/bin/bash

# Exit on error
set -e

# Install or update ASA server + verify installation
/opt/steamcmd/steamcmd.sh +force_install_dir /opt/server +login anonymous +app_update ${APPID} validate +quit

# Remove unnecessary files (saves 6.4GB.., that will be re-downloaded next update)
if [[ -n "${ARK_REDUCE_STORAGE_SIZE}" ]]; then 
    rm -rf /opt/server/ShooterGame/Binaries/Win64/ArkAscendedServer.pdb
    rm -rf /opt/server/ShooterGame/Content/Movies/
fi

# just update if any arg is given
if [[ -z $1 ]] ; then
  # when running as systemd then notify when ready
  if [[ -n $NOTIFY_SOCKET ]] ; then
    systemd-notify --ready --status "Steam is ready..."
  fi

  trap : TERM INT
  sleep infinity & wait
fi
