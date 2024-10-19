#!/bin/bash

_B="\033[0;1;30m"
_R="\033[0;1;31m"
_G="\033[0;1;32m"
_Y="\033[0;1;33m"
_B="\033[0;1;34m"
_P="\033[0;1;35m"
_C="\033[0;1;36m"
_W="\033[0;1;37m"
__="\033[0m"

RCON_CMDLINE=( rcon -a 127.0.0.1:${RCON_PORT} -p ${ARK_ADMIN_PASSWORD} )
EOS_FILE=/opt/manager/.eos.config
MAP_NAME=$(eval echo "$MAP_NAME")
SESSION_NAME=$(eval echo "$SESSION_NAME")
path="/var/backups/arkserver/${SESSION_NAME// /_}/${SERVER_MAP}"
state=$path/running
mkdir -p $path

get_and_check_pid() {
    # Get PID
    ark_pid=$(pgrep GameThread)
    if [[ -z "$ark_pid" ]]; then
        echo "0"
        return
    fi

    # Check process is still alive
    if ps -p $ark_pid > /dev/null; then
        echo "$ark_pid"
    else
        echo "0"
    fi
}

full_status_setup() {
    # Check PDB is still available
    if [[ ! -f "/opt/arkserver/ShooterGame/Binaries/Win64/ArkAscendedServer.pdb" ]]; then 
        echo "/opt/arkserver/ShooterGame/Binaries/Win64/ArkAscendedServer.pdb is needed to setup full status."
        return 1
    fi

    # Download pdb-sym2addr-rs and extract it to /opt/manager/pdb-sym2addr
    wget -q https://github.com/azixus/pdb-sym2addr-rs/releases/latest/download/pdb-sym2addr-x86_64-unknown-linux-musl.tar.gz -O /opt/manager/pdb-sym2addr-x86_64-unknown-linux-musl.tar.gz
    tar -xzf /opt/manager/pdb-sym2addr-x86_64-unknown-linux-musl.tar.gz -C /opt/manager
    rm /opt/manager/pdb-sym2addr-x86_64-unknown-linux-musl.tar.gz

    # Extract EOS login
    symbols=$(/opt/manager/pdb-sym2addr /opt/arkserver/ShooterGame/Binaries/Win64/ArkAscendedServer.exe /opt/arkserver/ShooterGame/Binaries/Win64/ArkAscendedServer.pdb DedicatedServerClientSecret DedicatedServerClientId DeploymentId)

    client_id=$(echo "$symbols" | grep -o 'DedicatedServerClientId.*' | cut -d, -f2)
    client_secret=$(echo "$symbols" | grep -o 'DedicatedServerClientSecret.*' | cut -d, -f2)
    deployment_id=$(echo "$symbols" | grep -o 'DeploymentId.*' | cut -d, -f2)

    # Save base64 login and deployment id to file
    creds=$(echo -n "$client_id:$client_secret" | base64 -w0)
    echo "${creds},${deployment_id}" > "$EOS_FILE"

    return 0
}

full_status_first_run() {
    #read -p "To display the full status, the EOS API credentials will have to be extracted from the server binary files and pdb-sym2addr-rs (azixus/pdb-sym2addr-rs) will be downloaded. Do you want to proceed [y/n]?: " -n 1 -r
    #if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    #    return 1
    #fi

    full_status_setup
    return $?
}

full_status_display() {
    creds=$(cat "$EOS_FILE" | cut -d, -f1)
    id=$(cat "$EOS_FILE" | cut -d, -f2)

    # Recover current ip
    ip=$(curl -s https://ifconfig.me/ip)

    # Recover and extract oauth token
    oauth=$(curl -s -H 'Content-Type: application/x-www-form-urlencoded' -H 'Accept: application/json' -H "Authorization: Basic ${creds}" -X POST https://api.epicgames.dev/auth/v1/oauth/token -d "grant_type=client_credentials&deployment_id=${id}")
    token=$(echo "$oauth" | jq -r '.access_token')

    # Send query to get server(s) registered under public ip
    res=$(curl -s -X "POST" "https://api.epicgames.dev/matchmaking/v1/${id}/filter"    \
        -H "Content-Type:application/json"      \
        -H "Accept:application/json"            \
        -H "Authorization: Bearer $token"       \
        -d "{\"criteria\": [{\"key\": \"attributes.ADDRESS_s\", \"op\": \"EQUAL\", \"value\": \"${ip}\"}]}")

    # Check there was no error
    if [[ "$res" == *"errorCode"* ]]; then
        echo "Failed to query EOS... Please run command again."
        full_status_setup
        return
    fi
    
    # Extract correct server based on server port
    serv=$(echo "$res" | jq -r ".sessions[] | select( .attributes.ADDRESSBOUND_s | contains(\":${SERVER_PORT}\"))")
    
    if [[ -z "$serv" ]]; then
        echo "Server is down"
        return
    fi

    # Extract variables
    mapfile -t vars < <(echo "$serv" | jq -r '
            .totalPlayers,
            .settings.maxPublicPlayers,
            .attributes.CUSTOMSERVERNAME_s,
            .attributes.DAYTIME_s,
            .attributes.SERVERUSESBATTLEYE_b,
            .attributes.ADDRESS_s,
            .attributes.ADDRESSBOUND_s,
            .attributes.MAPNAME_s,
            .attributes.BUILDID_s,
            .attributes.MINORBUILDID_s,
            .attributes.SESSIONISPVE_l,
            .attributes.ENABLEDMODS_s
        ')

    curr_players=${vars[0]}
    max_players=${vars[1]}
    serv_name=${vars[2]}
    day=${vars[3]}
    battleye=${vars[4]}
    ip=${vars[5]}
    bind=${vars[6]}
    map=${vars[7]}
    major=${vars[8]}
    minor=${vars[9]}
    pve=${vars[10]}
    mods=${vars[11]}
    bind_ip=${bind%:*}
    bind_port=${bind#*:}

    if [[ "${mods}" == "null" ]]; then
        mods="-"
    fi

    echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ Server Name:    ${serv_name}"
    echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ Map:            ${map}"
    echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ Day:            ${day}"
    echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ Players:        ${curr_players} / ${max_players}"
    echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ Mods:           ${mods}"
    echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ Server Version: ${major}.${minor}"
    #echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ Server Address: ${ip}:${bind_port}"
    echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ is up"
}

status() {
    enable_full_status=false
    # Execute initial EOS setup, true if no error
    if [[ "$1" == "--full" ]] ; then
        # If EOS file exists, no need to run initial setup
        if [[ -f "$EOS_FILE" ]]; then
            enable_full_status=true
        else
            full_status_first_run
            res=$?
            if [[ $res -eq 0 ]]; then
                enable_full_status=true
            fi
        fi
    fi

    # Get server PID
    ark_pid=$(get_and_check_pid)
    echo -ne "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ PID: "
    if [[ "$ark_pid" == 0 ]]; then
	echo "not found (server offline?)"
        return
    fi    
    echo -e "     ${ark_pid}"

    ark_port=$(ss -tupln | grep "GameThread" | grep -oP '(?<=:)\d+')
    echo -ne "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ Port: "
    if [[ -z "$ark_port" ]]; then
	echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ Not Listening"
        return
    fi

    echo -e "    ${ark_port}"

    # Check initial status with rcon command
    out=$(${RCON_CMDLINE[@]} ListPlayers 2>/dev/null)
    res=$?
    if [[ $res == 0 ]]; then
        # Once rcon is up, query EOS if requested
        if [[ "$enable_full_status" == true ]]; then
            full_status_display
        else            
            num_players=0
            if [[ "$out" != "No Players"* ]]; then
                num_players=$(echo "$out" | wc -l)
            fi
            echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ Players:        ${num_players} / ?"
            echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ is up"
        fi
    else
        echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ is down"
    fi
}

start() {
    # Check server not already running
    ark_pid=$(get_and_check_pid)
    if [[ "$ark_pid" != 0 ]]; then
        echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ is already running."
        return
    fi    

    echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ starting on port ${SERVER_PORT} ..."
    echo "-------- STARTING SERVER --------" >> $LOG_FILE

    # Start server in the background + nohup and save PID
    # TODO logging
    nohup /opt/manager/manager_server_start.sh >/dev/null 2>&1 &
    echo -ne "$_C"
    for i in $(seq 1 20)
    do
	sleep 1
	echo -n '.' >&2
	ark_pid=$(pgrep GameThread)
	if [[ ! -z $ark_pid ]]
	then
	    break
	fi
    done
    echo
    echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ PID: $ark_pid"

    sleep 10
    echo -ne "$_P"
    echo -n '.' >&2
    while [[ $(status) =~ 'down' ]] ; do
        echo -n '.' >&2
    done
    for i in 1 2 3 ; do
        echo -n '.' >&2
        sleep 10
    done
    echo
    echo "-------- SERVER STARTED --------" >> $LOG_FILE
    status --full
}

stop() {
    # Get server pid
    ark_pid=$(get_and_check_pid)
    if [[ "$ark_pid" == 0 ]]; then
        echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ PID not found (server offline?)"
        return
    fi    

    if [[ $1 != "--nosaveworld" ]]; then
        saveworld
    fi

    echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ stopping gracefully..."
    echo "-------- STOPPING SERVER --------" >> $LOG_FILE

    # Check number of players
    out=$(${RCON_CMDLINE[@]} DoExit 2>/dev/null)
    res=$?
    force=false
    if [[ $res == 0  && "$out" == "Exiting..." ]]; then
        echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ waiting ${SERVER_SHUTDOWN_TIMEOUT}s to stop..."
        timeout $SERVER_SHUTDOWN_TIMEOUT tail --pid=$ark_pid -f /dev/null
        res=$?

        # Timeout occurred
        if [[ "$res" == 124 ]]; then
            echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ still running"
            force=true
        else
	    echo "" 
        fi
    else
        force=true
    fi

    if [[ "$force" == true ]]; then
        echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ forcefully shutdown..."
        kill -INT $ark_pid

        timeout $SERVER_SHUTDOWN_TIMEOUT tail --pid=$ark_pid -f /dev/null
        res=$?
        # Timeout occurred
        if [[ "$res" == 124 ]]; then
            kill -9 $ark_pid
        fi
    fi

    echo "" > $PID_FILE
    echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ stopped."
    echo "-------- SERVER STOPPED --------" >> $LOG_FILE
}

restart() {
    stop "$1"
    start
}

saveworld() {
    # Get server pid
    ark_pid=$(get_and_check_pid)
    if [[ "$ark_pid" == 0 ]]; then
        echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ PID not found (server offline?)"
        return
    fi    

    echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ saving world ..."
    out=$(${RCON_CMDLINE[@]} SaveWorld 2>/dev/null)
    res=$?
    if [[ $res == 0 && "$out" == "World Saved" ]]; then
        echo "-------- SAVED WORLD --------" >> $LOG_FILE
        echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ world saved!"
    else
        echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ failed saving world."
    fi
}

custom_rcon() {
    # Get server pid
    ark_pid=$(get_and_check_pid)
    if [[ "$ark_pid" == 0 ]]; then
        echo -e "$_B$CLUSTER_ID$__ $_Y$MAP_NAME$__ PID not found (server offline?)"
        return
    fi    

    out=$(${RCON_CMDLINE[@]} "${@}" 2>/dev/null)
    echo "$out"
}

backup(){
    echo "Creating backup. Backups are saved in your ./ark_backup volume."
    # saving before creating the backup
    saveworld
    # sleep is nessecary because the server seems to write save files after the saveworld function ends and thus tar runs into errors.
    sleep 5
    # Use backup script
    /opt/manager/manager_backup.sh

    res=$?
    if [[ $res == 0 ]]; then
        echo "-------- BACKUP CREATED --------" >> $LOG_FILE
    else
        echo "creating backup failed"
    fi
}

restoreBackup(){
    backup_count=$(ls -1 /var/backups/arkserver/${SESSION_NAME// /_}/${SERVER_MAP}/backup* | wc -l)
    if [[ $backup_count > 0 ]]; then
        echo "Stopping the server."
        stop
        sleep 3
        # restoring the backup
        /opt/manager/manager_restore_backup.sh
        
        sleep 2
        start
    else
        echo "You haven't created any backups yet."
    fi
}



# Main function
main() {
    action="$1"
    option="$2"

    case "$action" in
	"resume")
            if [[ -f $state ]] ; then
              echo "-------- RESUMING PREVIOUS SERVER STATE --------" >> $LOG_FILE
              start
            fi 
            ;;
        "status")
            status "$option"
            ;;
        "start")
            start
	    touch $state
            ;;
        "halt")
            echo "-------- HALTING SERVER, KEEP STATE --------" >> $LOG_FILE
            stop "$option"
            ;;
        "stop")
            stop "$option"
	    rm -f $state
            ;;
        "restart")
            restart "$option"
            ;;
        "saveworld")
            saveworld
            ;;
        "rcon")
            custom_rcon "${@:2:99}"
            ;;
        "help")
            echo "Supported actions: status, start, stop, restart, saveworld, rcon, update, backup, restore."
            ;;
        "backup")
            backup
            ;;
        "restore")
            restoreBackup
            ;;
        *)
            echo "Invalid action. Supported actions: help, status, start, stop, restart, saveworld, rcon, update, backup, restore."
            exit 1
            ;;
    esac
}

# Check if at least one argument is provided
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <action> [--saveworld]"
    exit 1
fi

main "$@"
