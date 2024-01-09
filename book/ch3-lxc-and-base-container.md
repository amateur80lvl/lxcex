# Chapter 3.
# LXC and the base container

## Installing LXC

```bash
apt install debootstrap lxc lxcfs lxc-templates cgroupfs-mount \
libvirt0 libpam-cgfs uidmap debootstrap distro-info
```

Personally I don't use `lxc-net`, if you're not a fan of it too, make sure `/etc/default/lxc-net` contains:
```
USE_LXC_BRIDGE="false"
```
and run
```bash
invoke-rc.d lxc-net stop
update-rc.d lxc-net remove
```

## LXC security

This sections lists some points you should pay your attention to.

### Directory permissions

Don't let anyone list your containers:
```bash
chmod 751 /var/lib/lxc
```

### dmesg

On the host system add the following line to `/etc/sysctl.conf`:
```
kernel.dmesg_restrict = 1
```

### lxcfs

`lxcfs` improves container security by replacing some files in `/proc` and `/sys`
and its use is highly encouraged.
Sadly, it's not sufficient.

### procfs and sysfs

They both are mounted by default, exposing everything.
For example, you could deploy some [plausible deniability](https://github.com/amateur80lvl/pdt) scheme
but if your `/proc/cmdline` remains readable in the container where you're going to run
all potentially malicious software, your encryption may get no longer deniable.

You can turn this off by placing the following line in the end
of container's configuration file:
```
lxc.mount.auto=
```
This, however will make `lxcfs`, to fail because it depends on `/proc` and `/sys`.
You can fix `/usr/share/lxcfs/lxc.mount.hook`, see https://github.com/lxc/lxcfs/pull/625.

The position of empty `lxc.mount.auto` directive in the end of file is important.
Strictly speaking, it should be placed after all `lxc.include` directives, as long as
included files usually enable mounting everything after resetting `lxc.mount.auto`.
You can harden security of your containers by enabling only specific mounts.
Refer to `man lxc.container.conf` for details.
However, all those options aren't sufficient if you want to avoid leaking any sensitive
information about the base system to containers.

A way to hardening container security is custom mount hook for `/proc` and `/sys`
and we'll discuss this in next chapters in details.

In particular, procfs can be restricted with `hidepid` and `subset` options,
but AFAIK there's no way to restrict sysfs and one approach is mounting
`tmpfs` and `/dev/null` on directories and files you don't want to expose.
However bear in mind, root in the unprivileged container can unmount all your stubs
and get access to the original content.
Thus, even in unprivileged container don't run anything as root.


## Useful tools

LXC documentation is silent on how to remap UIDs and GIDs for your containers.
I found [this utility](https://bazaar.launchpad.net/~serge-hallyn/+junk/nsexec/download/head:/uidmapshift.c)
very simple and convenient.

You can download binary from [Releases](https://github.com/amateur80lvl/lxcex/releases) section
or compile it by yourself:
```bash
wget https://bazaar.launchpad.net/~serge-hallyn/+junk/nsexec/download/head:/uidmapshift.c
gcc -o /usr/local/bin/uidmapshift uidmapshift.c
strip /usr/local/bin/uidmapshift
```

## Initialization system for containers

Given that I try to avoid the mainstream init system, my choice for the host system was sysvinit.
However, it does not work well for containers.
IMAO, the best alternative to sysvinit is runit in native boot mode.

Normally, runit launches scripts from `/etc/rcS.d` and `/etc/rc2.d` at startup and from
`/etc/rc6.d` on shutdown. But if you create a couple of files, namely
`/etc/runit/native.boot.run` and `/etc/runit/no.emulate.sysv`, it will run scripts
only from `/etc/runit/boot-run` and `/etc/runit/shutdown.run`.
You'll have to create these directories as well.

I found native boot mode perfect for containers where you don't run many services.
Basically, you don't need anything in `/etc/runit/boot-run`,
however, you may find a few useful scripts
[over here](https://github.com/amateur80lvl/lxcex/tree/main/base-container/etc/runit/boot-run):
* [10-sysctl.sh](https://github.com/amateur80lvl/lxcex/tree/main/base-container/etc/runit/boot-run/10-sysctl.sh)
* [20-mount-run.sh](https://github.com/amateur80lvl/lxcex/tree/main/base-container/etc/runit/boot-run/20-mount-run.sh)
* [30-hostname.sh](https://github.com/amateur80lvl/lxcex/tree/main/base-container/etc/runit/boot-run/30-hostname.sh)
  (although, hostname is managed by LXC)
* [40-nftables.sh](https://github.com/amateur80lvl/lxcex/tree/main/base-container/etc/runit/boot-run/40-nftables.sh)


## The base container

Let's create and setup a container which we will use as the base for others.
You could use Devuan LXC template, but it will deploy sysvinit and other unnecessary things so
let's use `debootstrap` again:
```bash
mkdir -p /var/lib/lxc/base/rootfs

debootstrap --variant=minbase \
--include=apt-utils,bash-completion,bsdextrautils,console-setup,\
dialog,less,libc-l10n,locales,lsb-release,lsof,nano,procps,psutils,\
psmisc,runit,runit-init,tzdata \
--exclude=bootlogd,dmidecode,sysvinit-core,vim-common,vim-tiny \
daedalus /var/lib/lxc/base/rootfs \
http://deb.devuan.org/merged/
```
Notes on packages:
* console-setup is required for correct display of dialogs in linux terminal

You don't need all the tweaks you did for the base system.
To finish setting up the container chroot to it:
```bash
mount --bind /dev /var/lib/lxc/base/rootfs/dev
chroot /var/lib/lxc/base/rootfs
```

Configure locales
```bash
dpkg-reconfigure locales
```
and
[/etc/apt/sources.list](https://github.com/amateur80lvl/lxcex/tree/main/common-files/etc/apt/sources.list)
with
[01norecommends](https://github.com/amateur80lvl/lxcex/tree/main/common-files/etc/apt/apt.conf.d/01norecommends).

Plus, you will need to setup runit in native boot mode:
```bash
touch /etc/runit/native.boot.run
touch /etc/runit/no.emulate.sysv
mkdir /etc/runit/boot-run
mkdir /etc/runit/shutdown-run
for f in /etc/service/getty* ; do unlink $f ; done
```

Put the following files in `/etc/runit/boot-run`:
* [10-sysctl.sh](https://github.com/amateur80lvl/lxcex/tree/main/common-files/etc/runit/boot-run/10-sysctl.sh)
* [20-mount-run.sh](https://github.com/amateur80lvl/lxcex/tree/main/common-files/etc/runit/boot-run/20-mount-run.sh)

It's okay to exit chrooted environment now:
```bash
exit
umount /var/lib/lxc/base/rootfs/dev
```

Example configuration file `/var/lib/lxc/base/config`:
```
lxc.apparmor.profile = unconfined

lxc.rootfs.path = dir:/var/lib/lxc/base/rootfs

# Common configuration
lxc.include = /usr/share/lxc/config/devuan.common.conf

# lxcfs
lxc.mount.auto = cgroup:mixed
lxc.autodev = 1
lxc.include = /usr/share/lxc/config/common.conf.d/00-lxcfs.conf

# Container specific configuration
lxc.tty.max = 4
lxc.uts.name = base
lxc.arch = amd64
lxc.pty.max = 1024

lxc.start.auto = 0
```

You can test your container now:
```bash
lxc-start base
lxc-attach base
```

It's working, isn't it?

Clean it up:
```bash
apt clean
```
