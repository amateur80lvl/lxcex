INTERFACE=
IP_ADDRESS=
GATEWAY=

[ -f /etc/default/basic-networking ] && . /etc/default/basic-networking

ip address flush $INTERFACE

if ! ip link set dev $INTERFACE up ; then
    echo "Cannot set $INTERFACE up"
    exit 1
fi

if ! ip address add $IP_ADDR dev $INTERFACE ; then
    echo "Cannot assign address $IP_ADDR to $INTERFACE"
    exit 1
fi

if ! ip route add default via $GATEWAY ; then
    echo "Cannot set default gateway $GATEWAY"
    exit 1
fi

if [ -x /etc/nftables.conf ] && ! /etc/nftables.conf ; then
    echo "Cannot configure netfilter"
    exit 1
fi
