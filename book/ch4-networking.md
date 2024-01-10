# Chapter 4.
# Networking

A separate container greatly facilitates networking if you want different VPNs and routes
for different tasks. The base system provides a bridge interface, thus making up a backbone
for the internal network where IP addresses are truly static.

Here's an example how the internal network can be organized.
We will stick to this scheme where a single host bridge is shared by all containers.
But you can easily set up more elaborated configurations with multiple virtual networks.
```
+---------------+  +----------+   +-----------+ +-----------+
| Entertainment |  |   Work    |  |  Banking  | | Domestic  |
|   10.0.0.10   |  | 10.0.0.11 |  | 10.0.0.12 | | 10.0.0.13 |
|    Gateway:   |  | Gateway:  |  | Gateway:  | | Gateway:  |
|    10.0.0.3   |  | 10.0.0.4  |  | 10.0.0.5  | | 10.0.0.1  |
+-------+-------+  +-----+-----+  +-----+-----+ +-----+-----+
        |                |             |              | +-------------+
      +-+--------- virtual LAN ------+-+-----------+--+-| Base system |
      |               |              |             |    | 10.0.0.2    |
      |               |              |             |    | Gateway:    |
      |               |              |             |    | 10.0.0.1    |
      |               |              |             |    +-------------+
+-----+------+ +------+------+ +-----+-----+ +-----+----+
| Networking | | Tor service | | Wireguard | | OpenVPN  |
|  10.0.0.1  | |  10.0.0.3   | | 10.0.0.4  | | 10.0.0.5 |
|            | |  Gateway:   | | Gateway:  | | Gateway: |
| eth0,wlan0 | |  10.0.0.1   | | 10.0.0.1  | | 10.0.0.1 |
+------------+ +-------------+ +-----------+ +----------+
      |
 LAN/Internet
```

## Create networking container

Before reconfiguring the base system we should setup the networking container
but not to add physical adapters to it at the moment,
otherwise network connectivity will be lost.

Let's clone and extend the base container:
```bash
lxc-copy -n base -N networking
```

Don't start it, just chroot:
```bash
chroot /var/lib/lxc/networking/rootfs
```
and install a few more packages:
```bash
apt install apt-cacher-ng iproute2 iputils-ping\
iputils-tracepath iw netbase nftables rfkill\
tcpdump wireless-tools wpasupplicant
```
Apt-cacher-ng is started automatically, kill it for now and exit chrooted environment.


## Reconfigure the base system

At this point we have to replace `basic-networking` with a script that sets up a bridge.
Of course `lxc-net` could do that for you but we step down at deeper level and do this by hands.

First, stop and remove the `basic-networking`:
```bash
invoke-rc.d basic-networking stop
update-rc.d basic-networking remove
chmod -x /etc/init.d/basic-networking
```
This won't delete it forever and we remove executable bit with the last command just to make
`update-rc.d` happy.

Add [virtual-network](https://github.com/amateur80lvl/lxcex/tree/main/common-files/etc/init.d/virtual-network)
to `/etc/init.d/` and create configuration file `/etc/default/virtual-network` for it:
```
BRIDGE=br0
VETH_HOST_SIDE=vhost
VETH_BRIDGE_SIDE=vbridge
IP_ADDR=10.0.0.2/24
ROUTE1="default via 10.0.0.1"
ROUTE2="192.168.0.0/24 via 10.0.0.1"
```

The configuration supports up to 4 routes (arbitrary number would require bash instead of sh).
The default route for the base system points to the networking container.
Additional route assumes 192.168.0.0/24 is your LAN which you may want to access
seamlessly from the base system, without attaching to the networking container.

Let's install and start the service:
```bash
chmod +x  /etc/init.d/virtual-network
update-rc.d virtual-network defaults
invoke-rc.d virtual-network start
```

## Configure networking container

Add physical network adapters and veth device that makes connection with the host system bridge to
`/var/lib/lxc/networking/config`, e.g.:
```
lxc.net.0.type = veth
lxc.net.0.name = ethv
lxc.net.0.link = br0
lxc.net.0.flags = up
lxc.net.0.hwaddr = 00:16:7a:1f:d3:f5
lxc.net.0.ipv4.address = 10.0.0.1/24

lxc.net.1.type = phys
lxc.net.1.link = eth0
lxc.net.1.flags = up

lxc.net.2.type = phys
lxc.net.2.link = wlan0
#lxc.net.2.flags = up
```

This container will be unprivileged, so add the following as well:
```
lxc.include = /usr/share/lxc/config/devuan.userns.conf
lxc.idmap = u 0 100000 65536
lxc.idmap = g 0 100000 65536
```

Also, turn autostart on:
```
lxc.start.auto = 1
```

Plus, add the following line to both `/etc/subuid` and `/etc/subgid` in the base system:
```
root:100000:65536
```

Remap user and group:
```bash
uidmapshift -b /var/lib/lxc/networking 0 100000 65536
```

Although `ifupdown` could be the best choice, personaly I still use my
[basic-networking, adapted for runit](https://github.com/amateur80lvl/lxcex/tree/main/containers/networking/rootfs/etc/runit/boot-run/basic-networking.sh)
with configuration file
[etc/default/basic-networking](https://github.com/amateur80lvl/lxcex/tree/main/base-system/etc/default/basic-networking)
from the base system.

Configure NAT and a simple firewall with SSH DNAT -- see
[/etc/nftables.conf](https://github.com/amateur80lvl/lxcex/tree/main/base-system/etc/nftables.conf).
It will be started at boot by
[40-nftables.sh](https://github.com/amateur80lvl/lxcex/tree/main/containers/base/rootfs/etc/runit/boot-run/40-nftables.sh).

And don't forget to set `net.ipv4.ip_forward=1` in `/etc/sysctl.conf`.

## apt-cacher-ng

Apt cacher is a great tool to reduce network traffic when you deploy many containers.
The configuration file `/etc/apt-cacher-ng/acng.conf` needs the only change:
```
BindAddress: 10.0.0.1
```

Make sure the input filter chain in `/etc/nftables.conf` contains
```
# accept apt-cacher-ng
iif { ethv, lo } tcp dport 3142 accept
```

In all containers and in the base system you need to place
[00aptproxy](https://github.com/amateur80lvl/lxcex/tree/main/common-files/etc/apt/apt.conf.d/00aptproxy)
to `/etc/apt/apt.conf.d/`. It contains a single line:
```
Acquire::http::Proxy "http://10.0.0.1:3142";
```

How to setup runit service:
```bash
mkdir -p /etc/sv/apt-cacher-ng
```

Create
[/etc/sv/apt-cacher-ng/run](https://github.com/amateur80lvl/lxcex/tree/main/etc/sv/apt-cacher-ng/run)
file:
```bash
#!/usr/bin/env /lib/runit/invoke-run

exec 2>&1

if [ -e /etc/runit/verbose ]; then
        echo "invoke-run: starting ${PWD##*/}"
fi
exec chpst -u apt-cacher-ng /usr/sbin/apt-cacher-ng -c /etc/apt-cacher-ng ForeGround=1
```
and symlink it to `/etc/service`
```
ln -s /etc/sv/apt-cacher-ng /etc/service/
```
