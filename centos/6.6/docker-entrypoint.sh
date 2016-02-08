#!/bin/bash

set -e


function defaults {
    : ${ADMIN_DOMAIN:=dockerdomain}
    : ${CONFIG_DIR_ADMIN_ID:=admin}
    : ${CONFIG_DIR_ADMIN_PWD:=admin}
    : ${FULL_MACHINE_NAME:=ldap.dockerdomain}
    : ${ROOT_DN:="cn=Directory Manager"}
    : ${ROOT_DN_PWD:=admin}
    : ${SERVER_IDENTIFIER:=ldap}
    : ${SUFFIX:="dc=dockerdomain"}

    ROOT_DN_PWD_HASHED=$(pwdhash -s SSHA512 $ROOT_DN_PWD)

    : ${DOCKER_FIRSTRUN:=/var/lib/dirsrv/.docker_firstrun}

    export SERVER_IDENTIFIER ADMIN_DOMAIN
}

function bootstrap_etc() {
    if [ ! -d /etc/dirsrv/schema/ ]; then
        echo "Volume detected on /etc/dirsrv: copying back skeleton"
        rsync -av /etc/dirsrv-skel/ /etc/dirsrv/
    fi
}


function create_config() {
    echo "Creating config"
    cat > /etc/ds-setup.inf<<EOF
[General]
AdminDomain = ${ADMIN_DOMAIN}
ConfigDirectoryAdminID = ${CONFIG_DIR_ADMIN_ID}
ConfigDirectoryAdminPwd = ${CONFIG_DIR_ADMIN_PWD}
ConfigDirectoryLdapURL = ldap://${FULL_MACHINE_NAME}:389/o=NetscapeRoot
FullMachineName = ${FULL_MACHINE_NAME}
ServerRoot = /usr/lib64/dirsrv
SuiteSpotGroup = nobody
SuiteSpotUserID = nobody
[admin]
Port = 9830
ServerAdminID = ${CONFIG_DIR_ADMIN_ID}
ServerAdminPwd = ${CONFIG_DIR_ADMIN_PWD}
ServerIpAddress = 0.0.0.0
SysUser = nobody
[slapd]
AddOrgEntries = Yes
AddSampleEntries = No
HashedRootDNPwd = ${ROOT_DN_PWD_HASHED}
InstallLdifFile = suggest
RootDN = ${ROOT_DN}
RootDNPwd = ${ROOT_DN_PWD}
ServerIdentifier = ${SERVER_IDENTIFIER}
ServerPort = 389
SlapdConfigForMC = yes
Suffix = ${SUFFIX}
UseExistingMC = 0
bak_dir = /var/lib/dirsrv/slapd-${SERVER_IDENTIFIER}/bak
bindir = /usr/bin
cert_dir = /etc/dirsrv/slapd-${SERVER_IDENTIFIER}
config_dir = /etc/dirsrv/slapd-${SERVER_IDENTIFIER}
datadir = /usr/share
db_dir = /var/lib/dirsrv/slapd-${SERVER_IDENTIFIER}/db
ds_bename = userRoot
inst_dir = /usr/lib64/dirsrv/slapd-${SERVER_IDENTIFIER}
ldif_dir = /var/lib/dirsrv/slapd-${SERVER_IDENTIFIER}/ldif
localstatedir = /var
lock_dir = /var/lock/dirsrv/slapd-${SERVER_IDENTIFIER}
log_dir = /var/log/dirsrv/slapd-${SERVER_IDENTIFIER}
naming_value = ${SERVER_IDENTIFIER}
run_dir = /var/run/dirsrv
sbindir = /usr/sbin
schema_dir = /etc/dirsrv/slapd-${SERVER_IDENTIFIER}/schema
sysconfdir = /etc
tmp_dir = /tmp
EOF
}


function setup {
    chmod 777 /dev/shm

    echo -n "setup-ds-admin.pl"
    setup-ds-admin.pl --logfile /dev/stdout --silent --file /etc/ds-setup.inf

    echo -n "setup-ds-dsgw"
    setup-ds-dsgw

    # setup-ds-admin.pl automatically starts these services, but we'll
    # control them from supervisord. TODO if someone knows a way to _not_
    # start the services after setup-ds-admin.pl, I'm interested in it
    service dirsrv stop
    service dirsrv-admin stop
}


function firstrun {
    if ! [[ -f ${DOCKER_FIRSTRUN} ]]; then
        bootstrap_etc
        create_config
        setup
        touch ${DOCKER_FIRSTRUN}
    fi
}


echo "HOME is ${HOME}"
echo "WHOAMI is `whoami`"

defaults

firstrun

if [ "$1" = 'supervisord' ]; then
    echo "[Run] supervisord"
    /usr/bin/supervisord -c /etc/supervisord.conf -n
    exit 0
fi

echo "[RUN]: Builtin command not provided [supervisord]"
echo "[RUN]: $@"

exec "$@"
