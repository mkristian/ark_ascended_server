# ARK Survival Ascended Docker Server

This project relies on GloriousEggroll's Proton-GE in order to run the ARK Survival Ascended Server inside a docker container under Linux. This allows to run the ASA Windows server binaries on Linux easily.

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->
### Table of Contents
- [Usage](#usage)
- [Configuration](#configuration)
   * [Configuration variables](#configuration-variables)
- [Running multiple instances (cluster)](#running-multiple-instances-cluster)
- [Manager commands](#manager-commands)
- [Hypervisors](#hypervisors)

<!-- TOC end -->
### Setup

The whole setup assumes that this get installed on linux machine and it also assumes
that the git repository gets checkout into the home directory of a user. Best to setup
a new user (arkuser) :for this

```bash
sudo adduser arkserver
sudo su - arkserver # switch to this new user
```

Build the docker images (using podman)
```bash
podman build . -f Dockerfile.steamcmd -t kafka/steamcmd
podman build . -f Dockerfile.arkserver -t kafka/arkserver
```

Ensure container remains as they are after reboot. Assuming `arkserver` user.
```bash
loginctl enable-linger $USER 
```

Checkout this repository
```bash
git clone https://github.com/mkristian/ARK_Ascended_Docker.git $HOME
```

Setup the docker container as services
```bash
systemctl --user enable steamcmd.service
systemctl --user enable the_island.service
systemctl --user enable scorched_earth.service
```

Customize the configurations of the services
- common ENV: env
- the island: TheIsland/env
- scorched earth: ScorchedEarth/env
important is to ensure the different ports. See the diff
```bash
diff TheIsland/env ScorchedEarth/env
```


### Usage
Download the container by cloning the repo and setting permissions:
```bash
$ git clone https://github.com/AziXus/ARK_Ascended_Docker.git
$ cd ARK_Ascended_Docker
$ sudo chown -R 1000:1000 ./ark_*/
```

Before starting the container, edit the [.env](./.env) file to customize the starting parameters of the server. You may also edit [Game.ini](./ark_data/ShooterGame/Saved/Config/WindowsServer/Game.ini) and [GameUserSettings.ini](./ark_data/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini) for additional settings. Once this is done, start the container as follow:
```bash
$ docker compose up -d
```

During the startup of the container, the ASA server is automatically downloaded with `steamcmd` and subsequently started. You can monitor the progress with the following command:
```bash
$ ./manager.sh logs -f
asa_server  |[2023.10.31-17.06.19:714][  0]Log file open, 10/31/23 17:06:19
asa_server  |[2023.10.31-17.06.19:715][  0]LogMemory: Platform Memory Stats for WindowsServer
asa_server  |[2023.10.31-17.06.19:715][  0]LogMemory: Process Physical Memory: 319.32 MB used, 323.19 MB peak
asa_server  |[2023.10.31-17.06.19:715][  0]LogMemory: Process Virtual Memory: 269.09 MB used, 269.09 MB peak
asa_server  |[2023.10.31-17.06.19:715][  0]LogMemory: Physical Memory: 20649.80 MB used,  43520.50 MB free, 64170.30 MB total
asa_server  |[2023.10.31-17.06.19:715][  0]LogMemory: Virtual Memory: 33667.16 MB used,  63238.14 MB free, 96905.30 MB total
asa_server  |[2023.10.31-17.06.20:506][  0]ARK Version: 25.49
asa_server  |[2023.10.31-17.06.21:004][  0]Primal Game Data Took 0.35 seconds
asa_server  |[2023.10.31-17.06.58:846][  0]Server: "My Awesome ASA Server" has successfully started!
asa_server  |[2023.10.31-17.06.59:188][  0]Commandline:  TheIsland_WP?listen?SessionName="My Awesome ASA Server"?Port=7790?MaxPlayers=10?ServerPassword=MyServerPassword?ServerAdminPassword="MyArkAdminPassword"?RCONEnabled=True?RCONPort=32330?ServerCrosshair=true?OverrideStructurePlatformPrevention=true?OverrideOfficialDifficulty=5.0?ShowFloatingDamageText=true?AllowFlyerCarryPvE=true -log -NoBattlEye -WinLiveMaxPlayers=10 -ForceAllowCaveFlyers -ForceRespawnDinos -AllowRaidDinoFeeding=true -ActiveEvent=Summer
asa_server  |[2023.10.31-17.06.59:188][  0]Full Startup: 40.73 seconds
asa_server  |[2023.10.31-17.06.59:188][  0]Number of cores 6
asa_server  |[2023.10.31-17.07.03:329][  2]wp.Runtime.HLOD = "1"
```


### Configuration
The main server configuration is done through the [.env](./.env) file. This allows you to change the server name, port, passwords etc.

The server files are stored in a mounted volume in the [ark_data](./ark_data/) folder. The additional configuration files are found in this folder: [Game.ini](./ark_data/ShooterGame/Saved/Config/WindowsServer/Game.ini), [GameUserSettings.ini](./ark_data/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini).

Unlike ARK Survival Evolved, only one port must be exposed to the internet, namely the `SERVER_PORT`. It is not necessary to expose the `RCON_PORT`.

#### Configuration variables
We list some configuration options that may be used to customize the server below. Quotes in the `.env` file must not be used in most circumstances, you should only use them for certain flags such as `-BanListURL="http://banlist"`.

| Name | Description | Default |
| --- | --- | --- |
| SERVER_MAP | Server map. | TheIsland_WP |
| SESSION_NAME | Name of the server. | My Awesome ASA Server |
| SERVER_PORT | Server listening port. | 7790 |
| MAX_PLAYERS | Maximum number of players. | 10 |
| SERVER_PASSWORD | Password required to join the server. Comment the variable to disable it. | MyServerPassword |
| ARK_ADMIN_PASSWORD | Password required for cheats and RCON. | MyArkAdminPassword |
| RCON_PORT | Port used to connect through RCON. To access RCON remotely, uncomment `#- "${RCON_PORT}:${RCON_PORT}/tcp"` in `docker-compose.yml`. | 32330 |
| DISABLE_BATTLEYE | Comment to enable BattlEye on the server. | BattlEye Disabled |
| MODS | Comma-separated list of mods to install on the server. | Disabled |
| ARK_EXTRA_OPTS | Extra ?Argument=Value to add to the startup command. | ?ServerCrosshair=true?OverrideStructurePlatformPrevention=true?OverrideOfficialDifficulty=5.0?ShowFloatingDamageText=true?AllowFlyerCarryPvE=true |
| ARK_EXTRA_DASH_OPTS | Extra dash arguments to add to the startup command. | -ForceAllowCaveFlyers -ForceRespawnDinos -AllowRaidDinoFeeding=true -ActiveEvent=Summer |

To increase the available server memory, in [docker-compose.yml](./docker-compose.yml), increase the `deploy, resources, limits, memory: 16g` to a higher value.

### Running multiple instances (cluster)
If you want to run a cluster with two or more containers running at the same time, you will have to be aware of some things you have to change: 
- Clone this repository into two different directories like `git clone https://github.com/azixus/ARK_Ascended_Docker.git folder1` and `git clone https://github.com/azixus/ARK_Ascended_Docker.git folder2`
- First setup all instances according to the [usage](https://github.com/azixus/ARK_Ascended_Docker/edit/cluster/README.md#usage) and [configuration](https://github.com/azixus/ARK_Ascended_Docker/edit/cluster/README.md#configuration) steps.
- Create a folder in a directory of your choosing, e.g., `mkdir -p /opt/clusters`. This folder will be used by both instances to transfer player data.
- Edit the [docker-compose.yml](./docker-compose.yml) file in every instance by adding a volume for the newly created folder. The updated volume section should look as follows (focus on `/opt/clusters....`:
  ```yaml
  volumes:
    - ./ark_data:/opt/arkserver
    - ./ark_backup:/var/backups/asa-server
    - /opt/clusters:/opt/shared-cluster
    - steam_data:/opt/steamcmd
  ```
- Edit the [.env](./.env) file in every instance accordingly
  - Set the **port** to a different one for each instance, eg 7777, 7778, 7779 etc.
  - Edit `SERVER_MAP` to the map you want the server to run eg (`TheIsland_WP`, `ScorchedEarth_WP` etc)
  - Add line `COMPOSE_PROJECT_NAME=aprojectname` somewhere in the [.env](./.env) file with a different name for each instance. Please only use small letters, underscores and numbers.
  - Add `-clusterID=[yourclusterid]` to the `ARK_EXTRA_DASH_OPTS` with the same `clusterID` for every instance you want to cluster. The `clusterID` should be a random combination of letters and numbers, don't use special characters. The line should somewhat look like this:
    ```
    ARK_EXTRA_DASH_OPTS=-ForceAllowCaveFlyers -ForceRespawnDinos -AllowRaidDinoFeeding=true -ActiveEvent=Summer -clusterID=thisisarandomid -ClusterDirOverride="/opt/shared-cluster"
    ```
- Be sure that you have at least about **28-32GB** of memory available, especially if you use any mods
- Start every instance with `docker compose up -d` and enjoy your clustered ASA server :)

### Manager commands
The manager script supports several commands that we highlight below. 

**Server start**
```bash
$ ./manager.sh start
Starting server on port 7790
Server should be up in a few minutes
```

**Server stop**
```bash
$ ./manager.sh stop
Stopping server gracefully...
Waiting 30s for the server to stop
Done
```

**Server restart**
```bash
$ ./manager.sh restart
Stopping server gracefully...
Waiting 30s for the server to stop
Done
Starting server on port 7790
Server should be up in a few minutes
```

**Server status**  
The standard status command displays some basic information about the server, the server PID, the listening port and the number of players currently connected.
```bash
$ ./manager.sh status
Server PID:     109
Server Port:    7790
Players:        0 / ?
Server is up
```

**Server logs**\
_You can optionally use `./manager.sh logs -f` to follow the logs as they are printed._
```bash
$ ./manager.sh logs
ark_ascended_docker-asa_server-1  | Connecting anonymously to Steam Public...OK
ark_ascended_docker-asa_server-1  | Waiting for client config...OK
ark_ascended_docker-asa_server-1  | Waiting for user info...OK
ark_ascended_docker-asa_server-1  |  Update state (0x3) reconfiguring, progress: 0.00 (0 / 0)
ark_ascended_docker-asa_server-1  |  Update state (0x61) downloading, progress: 0.00 (0 / 9371487164)
ark_ascended_docker-asa_server-1  |  Update state (0x61) downloading, progress: 0.60 (56039216 / 9371487164)
ark_ascended_docker-asa_server-1  |  Update state (0x61) downloading, progress: 0.93 (86770591 / 9371487164)
ark_ascended_docker-asa_server-1  |  Update state (0x61) downloading, progress: 1.76 (164837035 / 9371487164)
# ... full logs will show
```

You can obtain more information with the `--full` flag which queries the Epic Online Services by extracting the API credentials from the server binaries.
```bash
./manager.sh status --full                                             
To display the full status, the EOS API credentials will have to be extracted from the server binary files and pdb-sym2addr-rs (azixus/pdb-sym2addr-rs) will be downloaded. Do you want to proceed [y/n]?: y
Server PID:     109
Server Port:    7790
Server Name:    My Awesome ASA Server
Map:            TheIsland_WP
Day:            1
Players:        0 / 10
Mods:           -
Server Version: 26.11
Server Address: 1.2.3.4:7790
Server is up
```

**Saving the world**
```bash
$ ./manager.sh saveworld
Saving world...
Success!
```

**Server update**
```bash
$ ./manager.sh update
Updating ARK Ascended Server
Saving world...
Success!
Stopping server gracefully...
Waiting 30s for the server to stop
Done
[  0%] Checking for available updates...
[----] Verifying installation...
Steam Console Client (c) Valve Corporation - version 1698262904
 Update state (0x5) verifying install, progress: 94.34 (8987745741 / 9527248082)
Success! App '2430930' fully installed.
Update completed
Starting server on port 7790
Server should be up in a few minutes
```

**Server create Backup**

The manager supports creating backups of your savegame and all config files. Backups are stores in the ./ark_backup volume. 

_No Server shutdown needed._
```bash
./manager.sh backup
Creating backup. Backups are saved in your ./ark_backup volume.
Saving world...
Success!
Number of backups in path: 6
Size of Backup folder: 142M     /var/backups/asa-server
```

**Server restore Backup**

The manager supports restoring a previously created backup. After using `./manager.sh restore` the manager will print out a list of all created backups and simply ask you which one you want to recover from.

_The server automatically get's restarted when restoring to a backup._
```bash
./manager.sh restore
Stopping the server.
Stopping server gracefully...
Waiting 30s for the server to stop
Done
Here is a list of all your backup archives:
1 - - - - - File: backup_2023-11-08_19-11-24.tar.gz
2 - - - - - File: backup_2023-11-08_19-13-09.tar.gz
3 - - - - - File: backup_2023-11-08_19-36-49.tar.gz
4 - - - - - File: backup_2023-11-08_20-48-44.tar.gz
5 - - - - - File: backup_2023-11-08_21-20-19.tar.gz
6 - - - - - File: backup_2023-11-08_21-21-10.tar.gz
Please input the number of the archive you want to restore.
4
backup_2023-11-08_20-48-44.tar.gz is getting restored ...
backup restored successfully!
Starting server on port 7790
Server should be up in a few minutes
```
**RCON commands**
```bash
$ ./manager.sh rcon "Broadcast Hello World"   
Server received, But no response!!
```
### Hypervisors

**Proxmox VM**

The default CPU type (kvm64) in proxmox for linux VMs does not seem to implement all features needed to run the server. When running the docker container check your log files in *./ark_data/ShooterGame/Saved/Logs* you might see a .crashstack file with contents similiar to:
```
Fatal error!

CL: 450696 
0x000000007b00cdb7 kernelbase.dll!UnknownFunction []
0x0000000143c738ca ArkAscendedServer.exe!UnknownFunction []
0x00000002c74d5ef7 ucrtbase.dll!UnknownFunction []
0x00000002c74b030b ucrtbase.dll!UnknownFunction []
0x00000001400243c2 ArkAscendedServer.exe!UnknownFunction []
0x0000000144319ec7 ArkAscendedServer.exe!UnknownFunction []
0x0000000141fa99ad ArkAscendedServer.exe!UnknownFunction []
0x000000014447c9b8 ArkAscendedServer.exe!UnknownFunction []
0x0000000145d2b64d ArkAscendedServer.exe!UnknownFunction []
0x0000000145d2b051 ArkAscendedServer.exe!UnknownFunction []
0x0000000145d2d732 ArkAscendedServer.exe!UnknownFunction []
0x0000000145d10425 ArkAscendedServer.exe!UnknownFunction []
0x0000000145d01628 ArkAscendedServer.exe!UnknownFunction []
```
In that case just change your CPU type to host in the hardware settings of your VM. After a restart of the VM the container should work without any issues.
