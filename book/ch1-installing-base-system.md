# Chapter 1.
# Installing the base system with debootstrap

I have a bad habit to use debootstrap everywhere for the smallest system it produces.
If you prefer an installer, you can glance at system tweaks and go to the next chapter.

Although you can use any distro for the base system, my choice is Devuan with sysvinit.
Not because I'm a fan of sysvinit, it's the worst init system IMAO :) but all others are even worse.
Devuan, at least, gives you the freedom of choice.


## Partitioning storage device

You can use any storage device and I presume it's an USB stick or SSD drive.
I play with 16GB USB flash drive and it's quite sufficient.

If your system can boot in legacy mode, one primary partition is enough.
For UEFI an additional small partition is required.

Format your primary partition as ext4, mount on `/mnt/devuan` and you're ready.


## If your current system is not Devuan

Get `debootstrap` then:
```bash
git clone https://git.devuan.org/devuan/debootstrap.git
export DEBOOTSTRAP_DIR=`realpath debootstrap`
```
plus keys:
```bash
gpg --no-default-keyring --keyserver keyring.devuan.org \
    --keyring ./devuan-keyring.gpg \
    --recv-keys 0022D0AB5275F140 94532124541922FB
```
and use `--keyring=./devuan-keyring.gpg` option for debootstrap command below.


## debootstrap

Assuming you have an USB stick formatted with ext4 and mounted on `/mnt/devuan`, run:
```bash
debootstrap --variant=minbase \
--include=acl,apparmor,apt-utils,bash-completion,bsdextrautils,\
chrony,console-setup,cpio,cron,dialog,ethtool,eudev,fdisk,file,\
findutils,gpm,iputils-ping,iputils-tracepath,iproute2,iw,less,\
libc-l10n,locales,lsb-release,lsof,man-db,manpages,nano,netbase,\
nftables,openssh-server,openssh-sftp-server,parted,pciutils,\
procps,psmisc,psutils,rfkill,rsync,rsyslog,screen,smartmontools,\
sudo,sysfsutils,tree,tzdata,usbutils,wireless-regdb,wpasupplicant,\
xz-utils,zstd \
--exclude=vim-common,vim-tiny \
daedalus /mnt/devuan \
http://deb.devuan.org/merged/
```

Notes on packages:
* `--exclude=vim-common,vim-tiny` is because of my ignorance, I always have to ask
  a search engine how to exit when I accidentally get in.
* `nano` - that's what I use instead
* `acl` is required to grant permissions on `/dev/dri`, etc. to containers
* `sudo` is required for "desktop integration" with containers
* `less` is not necessary if you can do without it
* `apparmor` is required by some packages
* `apt-utils` is what you surely need
* `dialog` is necessary for dpkg-reconfigure
* `eudev` is simply required
* `tzdata`, `lsb-release` are usually needed
* `console-setup` for keyboard layouts and console fonts
* `gpm` is needed if you want mouse in text console
* `libc-l10n`, `locales` are required for localization
* `man-db`, `manpages` are necessary unless you're going to read man pages elsewhere
* `ethtool`, `iputils-ping`, `iputils-tracepath`, `iproute2`, `iw`, `netbase`, `nftables`,
  `rfkill`, `wpasupplicant`: although the base system does not deal with networking hardware,
  these packages are needed for initial connectivity
* `wireless-regdb` is usually required by wireless drivers, otherwise they may puke their
  complaints over the boot screen
* `fdisk`, `parted` to manipulate partition tables on storage devices, although `fdisk` is not absolutely necessary
* `bash-completion`, `bsdextrautils`, `file`, `findutils`, `lsof`, `pciutils`, `procps`,
  `psmisc`, `psutils`, `screen`, `sysfsutils`, `tree`, `usbutils`, `xz-utils`
   are not absolutely necessary but can be very helpful
* `openssh-server`, `openssh-sftp-server`, `rsync` - I recommend to have these
  in the base system for backup purposes at least
* `chrony`, `cron`, `rsyslog` - that's what any distro must have
* `cpio`, `zstd` are needed by initramfs
* `smartmontools`: useful thing, I recommend to install it

Some of above packages can be installed implicitly as dependencies, but I prefer
to list them explicitly.
Of course, debootstrap installs a few more.


## chroot

Once the base system is debootstrapped, it's time to make some tweaks
and install kernel with bootloader.

First, chroot to your new system:
```bash
mount --bind /dev /mnt/devuan/dev
mount --bind /proc /mnt/devuan/proc
mount --bind /sys /mnt/devuan/sys

chroot /mnt/devuan
```

## Initial setup

### Locales, keyboard, and console

The very first recommended step is to configure locales.
```bash
dpkg-reconfigure locales
```

In the dialog choose locales you need, e.g.

* en_US.UTF-8
* ro_RO.UTF-8
* ru_RU.UTF-8
* ru_UA.UTF-8

and press OK. Also, you might need tweaks to `/etc/default/console-setup`
for correct display of national characters:
```
CHARMAP="UTF-8"
CODESET="CyrSlav"
```
And what I especially love Debian and derivatives for is keyboard configuration.
Make necessary tweaks to `/etc/default/keyboard`, i.e.:
```
XKBLAYOUT="us,ua,ro,ru"
XKBOPTIONS="grp:alt_shift_toggle"
```
A while ago, when I played with systemd-based Arch and derivatives, I could only dream of this.


### Configure APT package manager

Next, configure [/etc/apt/sources.list](https://github.com/amateur80lvl/lxcex/tree/main/common-files/etc/apt/sources.list):
```
deb http://deb.devuan.org/merged daedalus main contrib non-free non-free-firmware
deb http://deb.devuan.org/merged daedalus-security main contrib non-free non-free-firmware
deb http://deb.devuan.org/merged daedalus-updates main contrib non-free non-free-firmware
deb http://deb.devuan.org/merged daedalus-backports main contrib non-free non-free-firmware
```
and run
```bash
apt update
```

As long as our system is minimalistic, you might want, and I strongly
suggest to configure APT not to install recommended packages.
You'll need to place
[01norecommends](https://github.com/amateur80lvl/lxcex/tree/main/common-files/etc/apt/apt.conf.d/01 norecommends)
file in `/etc/apt/apt.conf.d`. It contains a couple of settings:
```
APT::Install-Recommends "0";
APT::Install-Suggests "0";
```

## Install kernel and bootloader packages

```bash
apt install linux-image-amd64 initramfs-tools grub2 firmware-linux-free \
firmware-linux-nonfree firmware-misc-nonfree firmware-realtek \
intel-microcode amd64-microcode
```

## Final tweaks

### /etc/fstab

Edit [/etc/fstab](https://github.com/amateur80lvl/lxcex/tree/main/base-system/etc/fstab).
Use your real UUID, you can find it in `blkid` output.
```
# <file system> <mount point>   <type>  <options>       <dump>  <pass>

UUID=12345678-9abc-def0-1234-567890abcdef / ext4 relatime,errors=remount-ro 0 1
tmpfs  /tmp      tmpfs  nosuid,nodev,mode=1777,size=32M       0 1
tmpfs  /var/log  tmpfs  nosuid,noexec,nodev,mode=755,size=8M  0 1
```
Notes:
* tmpfs mounts are key points for [plausible deniability](https://github.com/amateur80lvl/pdt).
  They prevent leaking of sensitive information down to unencrypted volume.
  For the same reason I don't use swap.
* Personally, I also use `commit=120` option to save flash lifetime.

### /etc/hostname and /etc/hosts

Write desired hostname to `/etc/hostname` and `/etc/hosts`.

### Disable Nvidia

Wayland may not work good with Nvidia cards. It does not work good either, but things
are much worse with Nvidia. You may need
[/etc/modprobe.d/blacklist-nvidia-nouveau.conf](https://github.com/amateur80lvl/lxcex/tree/main/base-system/etc/modprobe.d/blacklist-nvidia-nouveau.conf)
containing the following:
```
blacklist nouveau
options nouveau modeset=0
```

### Disable IPv6

If you don't need IPv6 for a variety of reasons (e.g. buggy resolver may try to get AAAA records first)
you can do this by adding the following lines to `/etc/sysctl.conf`:
```
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
```

### Set root password

My favorite password is qwerty. But I'm using plausible deniability, so don't
use the same unless you know what you're doing.

Anyway, you need to set password for root to be able to log in.

### Disable su root

Although this tweak is not necessary you may find it useful.
Add the following line to `/etc/pam.d/su` after `auth required pam_rootok.so`:
```
auth       requisite pam_rootok.so
```

### Configure and install bootloader

Systemd-based distros rename network adapters by default.
In Devuan the situation is opposite: you need to turn it on by adding `net.ifnames=1`
to GRUB_CMDLINE_LINUX in `/etc/default/grub`.

Renaming is performed by `udev` on the initial RAM disk (`initrd`) and to make changes
to take the effect you need to run
```bash
update-initramfs -u
```

You may also need some other boot options. For example, I had to add
`tsc=unstable lapic=notscdeadline intel_iommu=off` because kernel 6.x no longer
works on my old laptop without that.

When all necessary tweaks are made, install GRUB:
```bash
update-grub
grub-install /dev/<your-storage-device>
```

### Cleaning up

```bash
apt clean
```

### Boot from your media

It works, isn't it? No? It has to!


## Backup your new system

Assuming you mounted backup device as `/mnt/flash`,
```bash
mkdir -p /mnt/root
mount /dev/<your-boot-device> /mnt/root
rsync -rltvWpogH --devices --specials --delete /mnt/root/ /mnt/flash/
umount /mnt/root
```

## What's next?

* Close this book and walk [console way](https://unix.stackexchange.com/questions/117936/options-to-show-images-when-on-the-console).
* Go reading the next chapter of this nonsense.

Also, you can install `desktop-base` package for a nice GRUB theme.
It can't be installed at debootstrap stage because of weird dependencies
which debootstrap is unable to handle.
All packages it pulls aren't necessary for a pure console system,
but for graphical interface you'll need this anyway.
