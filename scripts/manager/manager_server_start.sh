#!/bin/bash
# This file is called by manager.sh to start a new instance of ASA

# Server main options
SESSION_NAME=$(eval echo "$SESSION_NAME")
cmd="${SERVER_MAP}?listen?SessionName=\"${SESSION_NAME}\"?Port=${SERVER_PORT}"
if [ -n "${MAX_PLAYERS}" ]; then
    cmd="${cmd}?MaxPlayers=${MAX_PLAYERS}"
fi

if [ -n "${SERVER_PASSWORD}" ]; then
    cmd="${cmd}?ServerPassword=${SERVER_PASSWORD}"
fi

if [ -n "${ARK_ADMIN_PASSWORD}" ]; then
    cmd="${cmd}?ServerAdminPassword=\"${ARK_ADMIN_PASSWORD}\""
fi

if [ -n "${RCON_PORT}" ]; then
    cmd="${cmd}?RCONEnabled=True?RCONPort=${RCON_PORT}"
fi

cmd="${cmd}${ARK_EXTRA_OPTS}"

# Server dash options
# Install mods
if [ -n "$MODS" ]; then
    ark_flags="${ark_flags} -mods=${MODS}"
fi

ark_flags="${ark_flags} -log"

if [ -n "${DISABLE_BATTLEYE}" ]; then 
    ark_flags="${ark_flags} -NoBattlEye"
else 
    ark_flags="${ark_flags} -BattlEye"
fi

if [ -n "${MAX_PLAYERS}" ]; then 
    ark_flags="${ark_flags} -WinLiveMaxPlayers=${MAX_PLAYERS}"
fi

if [ -n "${CLUSTER_ID}" ]; then
    CLUSTER_ID=$(eval echo "$CLUSTER_ID")
    ark_flags="${ark_flags} -clusterID=${CLUSTER_ID} -ClusterDirOverride=/opt/cluster"
fi

ark_flags="${ark_flags} ${ARK_EXTRA_DASH_OPTS}"

#fix for docker compose exec / docker exec parsing inconsistencies
STEAM_COMPAT_DATA_PATH=$(eval echo "$STEAM_COMPAT_DATA_PATH")
mkdir -p $STEAM_COMPAT_DATA_PATH

#starting server and outputting log file
echo "/opt/arkserver/ShooterGame/Binaries/Win64/ArkAscendedServer.exe ${cmd} ${ark_flags}" >> $LOG_FILE
proton run /opt/arkserver/ShooterGame/Binaries/Win64/ArkAscendedServer.exe ${cmd} ${ark_flags} >> $LOG_FILE 2>&1
