# AppHosting-SyslogNG
How to Application Host [create a Docker container] Syslog-NG in a Cisco Catalyst 9000 series switch

## Overview
Application Hosting, or AppHosting, on Cisco Catalyst 9000 Series switches allows a network administor to run applications as docker containers in a protected resource space of the switch. The benefits of providing an edge-computing function are various:
- Reduction in WAN traffic when data aggregration and filtering are employed
- Speed of processing when performed closer to the user/resource
- Optimized resource utilization of existing, spare capacity
- Disaggregation of work, allowing for higher reliability when distributed

To that end, this project describes how to use AppHosting to enable the use of Syslog-NG inside a container of the switch.

Syslog-NG is a robust Syslog event message handling solution that has existed in the open-source community for many years.

Why would we do this? Typical Syslog event provisioning in a network device allows for defining the syslog receiver, but it may not allow for sophisticated filtering or intent-based forwarding. Forwarding the syslog event messages into Syslog-NG permits the use of complex filtering and message multiplexing to suite our business needs.

## Prerequisites
### Switch Hardware and Software
The following hardware and software combinations are required:
- Minimum IOS XE 16.12.1 for Catalyst 9300 series switches
- Minimum IOS XE 17.1.1 for Catalyst 9400 series switches
- Minimum IOS XE 17.2.1 for Catalyst 9500-High Performance series switches
- Minimum IOS XE 17.2.1 for Catalyst 9600 series switches
- Minimum IOS XE 17.5.1 for Catalyst 9410 series switches
- Minimum IOS XE 17.7.1 for Catalyst 9500X series switches

Our environment was Catalyst 9300-48T running 17.3.3

### Container Storage
The container files must be stored on a filesystem accessible to the switch. Ideally the bootflash: filesystem, where the switch runtime binaries and log files are stored, is not used for functional segmentation, performance and duty cycle considerations.

The Catalyst 9300 and USB 3.0 120GB module was used for our purposes, but other switch models have alternatives.
- USB 3.0 SSD module
![](/images/2022-03-24-14-44-09.png)


[Installing a USB 3.0 SSD](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/hardware/install/b_c9300_hig/b_c9300_hig_chapter_01010.html) instructions

## Verify the IOx (IOs + linuX) application framework
```ios-xe
cat9k#show iox

IOx Infrastructure Summary:
---------------------------
IOx service (CAF) 1.11.0.5     : Running
IOx service (HA)               : Running
IOx service (IOxman)           : Running
IOx service (Sec storage)      : Not Running
Libvirtd 1.3.4                 : Running
Dockerd 18.03.0                : Running
Application DB Sync Info       : Available
Sync Status                    : Disabled

cat9k#
```

### If not running, enable IOx
```ios-xe
cat9k# configure terminal
Enter configuration commands, one per line.  End with CNTL/Z.
cat9k(config)#iox
cat9k(config)#
```

[Programmability Configuration Guide, Cisco IOS XE 17.3.x](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/prog/configuration/173/b_173_programmability_cg/application_hosting.html)


## Decide on network type
Options are:

Network Type | interface used
------------ | --------------
via Management port | app-vnic management
via front-panel trunk port | app-vnic AppGigbitEthernet trunk
via front-panel VLAN port | app-vnic AppGigabitEthernet (with vlan)
via IOS Network Address Translation (NAT) | ***

## Decide on using DHCP or static IP assignment
If using static IP assignment, then after the `<app-vnic>` configuration a subordinate `<guest-ipaddress>` configuration would be defined.

## Enter app-hosting config for app to be deployed
For our situation we're using management interface, statically assigned IP addresses and gateway. We are defining docker resources with `<run-opts>` to read files shared from the host system (Catalyst switch) into the container's default **/iox_data/appdata** directory. Another set of `<run-opts>` defines a restart directive and ports that will be exposed from the container to the host system. Finally we define a custom Resource Profile to allocate CPU, memory and persistent disk options.


### Our switch interface configlet
```ios-xe
interface GigabitEthernet0/0
 description Management Interface
 vrf forwarding Mgmt-vrf
 ip address 10.10.20.100 255.255.255.0
 negotiation auto
!
```

### Our switch app-hosting configlet
```ios-xe
app-hosting appid syslogng
 app-vnic management guest-interface 0
  guest-ipaddress 10.10.20.101 netmask 255.255.255.0
 app-default-gateway 10.10.20.254 guest-interface 0
 app-resource docker
  run-opts 1 "-v $(APP_DATA):/data"
  run-opts 3 "--restart=unless-stopped -p 514:514/udp -p 601:601/tcp"
 app-resource profile custom
  vcpu 1
  cpu 3700
  memory 1792
  persist-disk 200
```

## Build the container image
This process needs to be on a system other than the switch, such as a Linux VM with docker-engine installed.

If you need some guidance on doing this [here is a good link](https://docs.docker.com/engine/install/ubuntu/) for getting Docker engine installed on Ubuntu.

### Pull project from GitHub
blah

### Edit syslog-ng.conf to suit
Here is the [syslog-ng.conf](syslog-ng.conf) file you can review and edit to suit your needs.

### Build and save the docker image
```sh
docker build --tag syslogng:v1 .
docker save syslogng:v1 -o syslogng.tar
```

Example run:
```sh
AppHostingSyslogNG % docker build --tag syslogng:v1 .
[+] Building 24.3s (10/10) FINISHED
 => [internal] load build definition from Dockerfile                                          0.0s
 => => transferring dockerfile: 1.70kB                                                        0.0s
 => [internal] load .dockerignore                                                             0.0s
 => => transferring context: 2B                                                               0.0s
 => [internal] load metadata for docker.io/library/debian:testing                             0.5s
 => [1/5] FROM docker.io/library/debian:testing@sha256:56acc571843ffe0239c053896605530dac772  0.0s
 => [internal] load build context                                                             0.0s
 => => transferring context: 36B                                                              0.0s
 => CACHED [2/5] RUN apt-get update -qq && apt-get install -y     wget     ca-certificates    0.0s
 => CACHED [3/5] RUN wget -qO - https://ose-repo.syslog-ng.com/apt/syslog-ng-ose-pub.asc | g  0.0s
 => [4/5] RUN apt-get update -qq && apt-get install -y     libdbd-mysql libdbd-pgsql libdbd  22.0s
 => [5/5] ADD syslog-ng.conf /etc/syslog-ng/syslog-ng.conf                                    0.0s
 => exporting to image                                                                        1.6s
 => => exporting layers                                                                       1.6s
 => => writing image sha256:02282562c495d3f897983b001a1974aba4c9fd08ea01833fff6be215e3839168  0.0s
 => => naming to docker.io/library/syslogng:v1                                                0.0s
AppHostingSyslogNG % docker save syslogng:v1 -o syslogng.tar
AppHostingSyslogNG % ls -lh syslogng.tar
-rw-------  1 jadavis  staff   355M Mar 24 15:29 syslogng.tar
```

## Transfer docker image to switch flash
We now need to get the docker .tar image onto the switch flash, specifically `usbflash1:` for the Catalyst 9300 in our lab. Using the USB 3.0 SSD flash will allow for better speed, flash longevity/duty-cycle, and capacity.

To keep our flash file-system tidy I suggest creating and using a directory for the container .tar file and any other files that might be associated to the project. For our situation the project directory would be `usbflash1:syslogng.d`

```ios-xe
copy scp: usbflash1:<container_dir>
```

Example run: 

[*note: in our environment we must transfer through Mgmt-vrf*]
```ios-xe
cat9k#mkdir usbflash1:syslogng
Create directory filename [syslogng]?
Created dir usbflash1:/syslogng
cat9k#copy scp: usbflash1: vrf Mgmt-vrf
Address or name of remote host []? 10.10.20.20
Source username [admin]? developer
Source filename []? Downloads/syslogng.tar
Destination filename [syslogng.tar]? syslogng/syslogng.tar
Password:
 Sending file modes: C0644 372416000 syslogng.tar
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
(MASS amounts of ! progress indicators removed)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!
372416000 bytes copied in 197.600 secs (1884696 bytes/sec)
cat9k#
```

## Install, Activate, Start container
The following command will install the newly copied `usbflash1:syslogng/syslogng.tar` file with an appid (application id) of `syslogng`.

```ios-xe
cat9k#app-hosting install appid syslogng package usbflash1:syslogng/syslogng.tar
Installing package 'usbflash1:syslogng/syslogng.tar' for 'syslogng'. Use 'show app-hosting list' for progress.
```

This next command will show the container was installed, as DEPLOYED status.

```ios-xe
cat9k#show app-hosting list
App id                                   State
---------------------------------------------------------
syslogng                                 DEPLOYED
```

This next command will activate the container. It is followed by the `show app-hosting list` command to double-check the status is ACTIVATED.
```ios-xe
cat9k#app-hosting activate appid syslogng
syslogng activated successfully
Current state is: ACTIVATED

cat9k#show app-hosting list
App id                                   State
---------------------------------------------------------
syslogng                                 ACTIVATED
```

The `show app-hosting detail appid` command with the specific appid provides further detail about the container status. It can be helpful in reviewing state, file locations, resource reservations, and network parameters.

```ios-xe
cat9k#show app-hosting detail appid syslogng
App id                 : syslogng
Owner                  : iox
State                  : ACTIVATED
Application
  Type                 : docker
  Name                 : syslogng
  Version              : v1
  Description          :
  Path                 : usbflash1:syslogng/syslogng.tar
  URL Path             :
Activated profile name : custom

Resource reservation
  Memory               : 1792 MB
  Disk                 : 200 MB
  CPU                  : 3700 units
  VCPU                 : 1

Attached devices
  Type              Name               Alias
  ---------------------------------------------
  serial/shell     iox_console_shell   serial0
  serial/aux       iox_console_aux     serial1
  serial/syslog    iox_syslog          serial2
  serial/trace     iox_trace           serial3

Network interfaces
   ---------------------------------------
eth0:
   MAC address         : 52:54:dd:73:dc:78
   IPv4 address        : 10.10.20.101
   Network name        : mgmt-bridge100


Docker
------
Run-time information
  Command              :
  Entry-point          :  /usr/sbin/syslog-ng -F
  Run options in use   : -v $(APP_DATA):/data --restart=unless-stopped -p 514:514/udp -p 601:601/tcp
  Package run options  :
Application health information
  Status               : 0
  Last probe error     :
  Last probe output    :


cat9k#app-hosting start appid syslogng
syslogng started successfully
Current state is: RUNNING
cat9k#
```

## Access image shell
The `app-host connect appid` command is used to connect to a session of the container.
```iox-xe
cat9k#app-hosting connect appid syslogng session
# uname -a
Linux a465d4787620 4.19.157 #1 SMP Wed Feb 10 10:15:44 UTC 2021 x86_64 GNU/Linux
#
```


We can note the `syslog-ng.conf` file was copied during the docker build and incorporated into the correct location.

```ios-xe
cat9k#app-hosting connect appid syslogng session
# cat /etc/syslog-ng/syslog-ng.conf
@version: 3.35
@include "scl.conf"

options {
    time-reap(30);
    mark-freq(10);
    keep-hostname(yes);
    chain-hostnames(no);
    create_dirs(yes);
};

source s_net { default-network-drivers(); };

filter f_ACL-violation {
  match("SEC-6-IPACCESSLOG" value("MESSAGE")) and
  match("SYS-5-PRIV_AUTH_FAIL" value("MESSAGE"))
};

#destination d_securityapp { udp("<CiscoSecureNetworkAnalytics>" port(514)); };

#destination d_DNAC { udp("<DNACenter>" port(514)); };

#destination d_LOGArchive { udp("<LOGArchive>" port(514)); };

destination d_localfile { file("/var/log/syslogng-${YEAR}/${MONTH}-${DAY}/messages"); };

destination d_localfile_sec { file("/var/log/syslogng-${YEAR}/${MONTH}-${DAY}/security_messages");};

log { source(s_net);
      filter(f_ACL-violation);
      #destination(d_securityapp);
      destination(d_localfile_sec);
    };
log { source(s_net);
      #destination(d_DNAC);
      #destination(d_LOGArchive);
      destination(d_localfile);
    };
#
```

## (Optional) Update syslog-ng.conf file
You may have occasion to update the `syslog-ng.conf` file. The container does the have the `vi` utility installed, but if your changes are significant it may make sense to edit them off-box and copy them into the switch container environment.

- copy file from switch console using SCP with source being off-box and target being switch's `usbflash1:` and container directory. Answer the prompted questions about server hostname/IP, directory/filename as appropriate.
    ```ios-xe
    copy scp: usbflash1:<container_dir>
    ```
- Use `app-host data copy file` to bring the copied file from the switch's filesystem into the container's filesystem.
    ```ios-xe
    app-hosting data appid syslogng copy usbflash1:syslogng.d/syslog-ng.conf /syslog-ng.conf
    ```

- Use `app-hosting connect` to access the container shell
    ```ios-xe
    app-hosting connect appid syslogng session
    ```

- from within container look for the updated file to copy to correct location, typically `/etc/syslog-ng` local to the container environment.  Then issue a `syslog-ng-ctl reload` command to force Syslog-NG to re-read the configuration file.
    ```sh
    copy /iox_data/appdata/syslog-ng.conf /etc/syslog-ng/syslog-ng.conf
    syslog-ng-ctl reload
    ```

## (Optional) Extract/download container logs
The sample `syslog-ng.conf` file has a suggested `destination d_localfile` parameter to drop messages into a container-local file `/var/log/syslogng-YYYY/MM-DD/messages`. It is prudent to monitor the growth of the `/var/log/syslogng-*` directories for filespace usage. The container image was built with the `scp` utility, so you can copy files OFF the container to any other fileserver supporting SCP.

```ios-xe
# scp developer@10.10.20.20:Downloads/syslogng-2022-0325.log /var/log/syslogng-2022/03-25/messages
The authenticity of host '10.10.20.20 (10.10.20.20)' can't be established.
ED25519 key fingerprint is SHA256:MbXlsdtKy1J+Tj67hyVRPz5URQS/6eT2ILljoG1ihqA.
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '10.10.20.20' (ED25519) to the list of known hosts.
developer@10.10.20.20's password:
messages                                       100%  274KB  59.4MB/s   00:00
# 
```


## How to stop, deactivate, uninstall
The following commands allow you to stop, deactivate and uninstall the container. Use stop if you need to stop the run-time usage of the container.  Use stop, then deactivate, if you need to update the container resource reservations (but keep the base image). Use stop, then deactivate, then uninstall if you need to remove the current container image so you can replace with a newer version, if necessary.
```ios-xe
cat9k#app-hosting stop appid syslogng
cat9k#app-hosting deactivate appid syslogng
cat9k#app-hosting uninstall appid syslogng
```

## Enable switch logging to embedded container
We must update the hosting switch configuration to forward syslog event messages into the cotainer. Ensure you're using the correct IP address of the container. Note other network devices can forward their syslog event messages into the same container - they do not need to host their own container running Syslog-NG.  Use the same configuration guidelines.
```ios-xe
cat9k#conf t
Enter configuration commands, one per line.  End with CNTL/Z.
cat9k(config)#logging host 10.10.20.101 vrf Mgmt-vrf
cat9k(config)#exit
cat9k#copy runn start
Destination filename [startup-config]?
Building configuration...
[OK]
```
### Verify Syslog event messages (local to switch)
Use the following commands to verify Syslog event messages local to the switch. Then it is appropriate to access the container environment to check the `/var/log/syslogng-YYYY/MM-DD/messages` file for similar entries...or check any other apps that had messages forwarded to them.

```ios-xe
cat9k#show logg last 40
Syslog logging: enabled (0 messages dropped, 2 messages rate-limited, 0 flushes, 0 overruns, xml disabled, filtering disabled)

No Active Message Discriminator.



No Inactive Message Discriminator.


    Console logging: disabled
    Monitor logging: level debugging, 40 messages logged, xml disabled,
                     filtering disabled
    Buffer logging:  level debugging, 411 messages logged, xml disabled,
                    filtering disabled
    Exception Logging: size (4096 bytes)
    Count and timestamp logging messages: disabled
    File logging: disabled
    Persistent logging: disabled

No active filter modules.

    Trap logging: level informational, 369 message lines logged
        Logging to 10.10.20.20  (udp port 514, audit disabled,
              link up),
              145 message lines logged,
              0 message lines rate-limited,
              0 message lines dropped-by-MD,
              xml disabled, sequence number disabled
              filtering disabled
        Logging to 10.10.20.101  (Mgmt-vrf) (udp port 514, audit disabled,
              link up),
              3 message lines logged,
              0 message lines rate-limited,
              0 message lines dropped-by-MD,
              xml disabled, sequence number disabled
              filtering disabled
        Logging Source-Interface:       VRF Name:

Showing last 40 lines

Log Buffer (102400 bytes):

.Mar 24 15:21:18.455: %SYS-5-CONFIG_I: Configured from console by admin on vty0 (192.168.254.11)
.Mar 24 15:21:18.457: %DMI-5-SYNC_NEEDED: Switch 1 R0/0: dmiauthd: Configuration change requiring running configuration sync detected - ''. The running configuration will be synchronized  to the NETCONF running data store.
.Mar 24 15:21:28.413: %DMI-5-SYNC_COMPLETE: Switch 1 R0/0: dmiauthd: The running configuration has
been synchronized to the NETCONF running data store.
.Mar 24 15:44:09.911: %IM-6-INSTALL_MSG: Switch 1 R0/0: ioxman: app-hosting: Uninstall succeeded: syslogng uninstalled successfully
.Mar 24 15:47:30.672: %IM-6-INSTALL_MSG: Switch 1 R0/0: ioxman: app-hosting: Install succeeded: syslogng installed successfully Current state is DEPLOYED
.Mar 24 16:07:26.494: %SYS-6-TTY_EXPIRE_TIMER: (exec timer expired, tty 1 (192.168.254.11)), user admin
.Mar 24 16:07:26.494: %SYS-6-LOGOUT: User admin has exited tty session 1(192.168.254.11)
.Mar 24 17:00:03.526: %SEC_LOGIN-5-LOGIN_SUCCESS: Login Success [user: admin] [Source: 192.168.254.11] [localport: 22] at 17:00:03 UTC Thu Mar 24 2022
.Mar 24 17:04:00.640: %SYS-5-CONFIG_I: Configured from console by admin on vty0 (192.168.254.11)
.Mar 24 17:04:00.642: %DMI-5-SYNC_NEEDED: Switch 1 R0/0: dmiauthd: Configuration change requiring running configuration sync detected - ''. The running configuration will be synchronized  to the NETCONF running data store.
.Mar 24 17:04:10.691: %DMI-5-SYNC_COMPLETE: Switch 1 R0/0: dmiauthd: The running configuration has
been synchronized to the NETCONF running data store.
.Mar 24 17:05:49.887: %SYS-5-CONFIG_I: Configured from console by admin on vty0 (192.168.254.11)
.Mar 24 17:05:49.888: %DMI-5-SYNC_NEEDED: Switch 1 R0/0: dmiauthd: Configuration change requiring running configuration sync detected - ''. The running configuration will be synchronized  to the NETCONF running data store.
.Mar 24 17:05:59.706: %DMI-5-SYNC_COMPLETE: Switch 1 R0/0: dmiauthd: The running configuration has
been synchronized to the NETCONF running data store.
.Mar 24 17:06:55.146: %IM-6-ACTIVATE_MSG: Switch 1 R0/0: ioxman: app-hosting: Activate succeeded: syslogng activated successfully Current state is in ACTIVATED
.Mar 24 17:17:07.858: %SYS-6-TTY_EXPIRE_TIMER: (exec timer expired, tty 1 (192.168.254.11)), user admin
.Mar 24 17:17:07.858: %SYS-6-LOGOUT: User admin has exited tty session 1(192.168.254.11)
.Mar 24 17:24:00.819: %SEC_LOGIN-5-LOGIN_SUCCESS: Login Success [user: admin] [Source: 192.168.254.11] [localport: 22] at 17:24:00 UTC Thu Mar 24 2022
.Mar 24 17:49:52.259: %IM-6-START_MSG: Switch 1 R0/0: ioxman: app-hosting: Stop succeeded: syslogng stopped successfully Current state is in STOPPED
.Mar 24 18:02:56.075: %IM-6-START_MSG: Switch 1 R0/0: ioxman: app-hosting: Stop succeeded: syslogng stopped successfully Current state is in STOPPED
.Mar 24 18:03:57.530: %IM-6-DEACTIVATE_MSG: Switch 1 R0/0: ioxman: app-hosting: Deactivate succeeded: syslogng deactivated successfully Current state is in DEPLOYED
.Mar 24 18:08:11.835: %IM-6-INSTALL_MSG: Switch 1 R0/0: ioxman: app-hosting: Uninstall succeeded: syslogng uninstalled successfully
.Mar 24 18:28:58.190: %SYS-6-TTY_EXPIRE_TIMER: (exec timer expired, tty 1 (192.168.254.11)), user admin
.Mar 24 18:28:58.190: %SYS-6-LOGOUT: User admin has exited tty session 1(192.168.254.11)
.Mar 24 18:30:25.948: %SEC_LOGIN-5-LOGIN_SUCCESS: Login Success [user: admin] [Source: 192.168.254.11] [localport: 22] at 18:30:25 UTC Thu Mar 24 2022
.Mar 24 18:35:00.570: %SYS-5-CONFIG_I: Configured from console by admin on vty0 (192.168.254.11)
.Mar 24 18:35:00.572: %DMI-5-SYNC_NEEDED: Switch 1 R0/0: dmiauthd: Configuration change requiring running configuration sync detected - ''. The running configuration will be synchronized  to the NETCONF running data store.
.Mar 24 18:35:10.465: %DMI-5-SYNC_COMPLETE: Switch 1 R0/0: dmiauthd: The running configuration hasbeen synchronized to the NETCONF running data store.
.Mar 24 18:47:44.288: %SYS-6-TTY_EXPIRE_TIMER: (exec timer expired, tty 1 (192.168.254.11)), user admin
.Mar 24 18:47:44.288: %SYS-6-LOGOUT: User admin has exited tty session 1(192.168.254.11)
.Mar 24 19:06:48.604: %SEC_LOGIN-5-LOGIN_SUCCESS: Login Success [user: admin] [Source: 192.168.254.11] [localport: 22] at 19:06:48 UTC Thu Mar 24 2022
.Mar 24 19:17:09.441: %SYS-6-TTY_EXPIRE_TIMER: (exec timer expired, tty 1 (192.168.254.11)), user admin
.Mar 24 19:17:09.442: %SYS-6-LOGOUT: User admin has exited tty session 1(192.168.254.11)
.Mar 24 20:12:37.433: %SEC_LOGIN-5-LOGIN_SUCCESS: Login Success [user: admin] [Source: 192.168.254.11] [localport: 22] at 20:12:37 UTC Thu Mar 24 2022
.Mar 24 20:17:03.508: %SMART_LIC-3-COMM_FAILED: Communications failure with the Cisco Smart License Utility (CSLU) : Unable to resolve server hostname/domain name
.Mar 24 20:27:36.216: %IM-6-INSTALL_MSG: Switch 1 R0/0: ioxman: app-hosting: Install succeeded: syslogng installed successfully Current state is DEPLOYED
.Mar 24 20:29:00.445: %IM-6-ACTIVATE_MSG: Switch 1 R0/0: ioxman: app-hosting: Activate succeeded: syslogng activated successfully Current state is in ACTIVATED
.Mar 24 20:53:11.139: %SYS-6-LOGGINGHOST_STARTSTOP: Logging to host 10.10.20.101 port 0 CLI Request Triggered
.Mar 24 20:53:12.138: %SYS-6-LOGGINGHOST_STARTSTOP: Logging to host 10.10.20.101 port 514 (Mgmt-vrf) started - CLI initiated
.Mar 24 20:53:22.019: %SYS-5-CONFIG_I: Configured from console by admin on vty0 (192.168.254.11)
cat9k#
```
