#!/bin/bash
# 
# auto start
# sleep 60
# /usr/syno/etc/rc.sysv/Galaxy_NAT.sh start#
#
# /usr/syno/etc/rc.sysv/Galaxy_NAT.sh
# Change this variable to match your private network.
PRIVATE_NETWORK="10.20.0.0/24"
#
# Change this variable to match your public interface - either eth0 or eth1
PUBLIC_INTERFACE="eth0"

# Set PATH to find iptables
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/syno/sbin:/usr/syno/bin

# Module list where KERNEL_MODULES_NAT are defined.
IPTABLES_MODULE_LIST="/usr/syno/etc/iptables_modules_list"
source "${IPTABLES_MODULE_LIST}"

# Tool to load kernel modules (modprobe does not work for me)
BIN_SYNOMODULETOOL="/usr/syno/bin/synomoduletool"

# My service name - let's make sure we don't conflict with synology
SERVICE="Galaxy_NAT"

# iptable binary
IPTABLES="iptables"

start() {
    # Log execution time
    date

    # Make sure packet forwarding is enabled.
    # 'sysctl -w net.ipv4.ip_forward=1' does not work for me
    echo 1 > /proc/sys/net/ipv4/ip_forward

    # Count the number of modules so that we can verify if the module
    # insertion was successful. We replace whitespaces with newlines
    # and count lines.
    MODULE_COUNT=$(
        echo "${KERNEL_MODULES_NAT}" |
            gawk '{ print gensub(/\s+/, "\n", "g") }' |
            wc -l
    )

    # Load the kernel modules necessary for NAT
    "${BIN_SYNOMODULETOOL}" --insmod "${SERVICE}" ${KERNEL_MODULES_NAT}
    RV=$?

    # $BIN_SYNOMODULETOOL returns the number of loaded modules as return value
    [[ "${RV}" == "${MODULE_COUNT}" ]] || {
            echo >&2 "Error: Modules were not loaded. The following command failed:"
            echo >&2 "${BIN_SYNOMODULETOOL}" --insmod "${SERVICE}" ${KERNEL_MODULES_NAT}
            exit 1
        }

    # Turn on NAT.
    "${IPTABLES}" -t nat -A POSTROUTING -s "${PRIVATE_NETWORK}" -j MASQUERADE -o "${PUBLIC_INTERFACE}"
    RV=$?
    [[ "${RV}" == "0" ]] || {
            echo >&2 "Error: MASQUERADE rules could not be added. The following command failed:"
            echo >&2 "${IPTABLES}" -t nat -A POSTROUTING -s "${PRIVATE_NETWORK}" -j MASQUERADE -o "${PUBLIC_INTERFACE}"
            exit 1
        }

    # Log current nat table
    iptables -L -v -t nat
}

case "$1" in
        start)
                start
                exit
                ;;
        *)
                # Help message.
                echo "Usage: $0 start"
                exit 1
                ;;
esac