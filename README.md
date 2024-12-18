# LXCex

Lightweight privacy-focused desktop operating system based on Devuan and LXC.
A project for self-education, and yet another attempt to make an alternative
to [Qubes OS](https://www.qubes-os.org/).
This is not a distro yet and probably never will.
This is a set of files and patches, a simple `makecex` script,
and an instruction à la [LFS](https://www.linuxfromscratch.org/).

Work in progress.


## Overview

* The base system (host system, or Dom0 in terms of Qubes) is running Sway.
* Networking container manages all physical devices, runs firewall and apt-cacher-ng.
* Virtual internal network provides truly static IP addresses to containers,
  making more or less complex routing robust when external IP address and/or devices change.
* Additional networking containers may run different VPNs for work, entertainment, banking, etc.
* User containers run Weston, Cage, Xwayland, etc. instances which get nested in Sway.

At the moment, this system reflects my experience and is full of personal preferences.
Some of them are quite baseless.
I swear I'll get rid of them as soon as the number of users will go beyond 1.5.
But in general, the rationale is as follows:

## Rationale

* keep attack surface and fingerprinting surface as small as possible
* make [plausible deniability](https://github.com/amateur80lvl/pdt) easy

## Installation

### makecex

A bootable media with live system can be generated with
[makecex](https://github.com/amateur80lvl/lxcex/tree/main/makecex).
You'll need a PPA which can be created with
[prepare](https://github.com/amateur80lvl/lxcex/tree/main/packages/prepare) and
[build](https://github.com/amateur80lvl/lxcex/tree/main/packages/build) scripts.

Only legacy boot mode is supported for amd64 for now.

The script contains parameters at the beginning, revise them carefully before running.
You can write modified parameters to `makecex.conf` instead of making changes to the script.


### by hands

* [Chapter 1. Installing the base system with debootstrap](https://github.com/amateur80lvl/lxcex/tree/main/book/ch1-installing-base-system.md)
* [Chapter 2. The basic networking](https://github.com/amateur80lvl/lxcex/tree/main/book/ch2-basic-networking.md)
* [Chapter 3. LXC and the base container](https://github.com/amateur80lvl/lxcex/tree/main/book/ch3-lxc-and-base-container.md)
* [Chapter 4. Networking](https://github.com/amateur80lvl/lxcex/tree/main/book/ch4-networking.md)
* [Chapter 5. Desktop Environment](https://github.com/amateur80lvl/lxcex/tree/main/book/ch5-desktop-environment.md)
* [Chapter 6. Pipewire](https://github.com/amateur80lvl/lxcex/tree/main/book/ch6-pipewire.md)
* [Chapter 7. Plausible Deniability](https://github.com/amateur80lvl/lxcex/tree/main/book/ch7-plausible-deniability.md)
* [Chapter 8. Sharing files](https://github.com/amateur80lvl/lxcex/tree/main/book/ch8-sharing-files.md)


## Experience

Drafts/Sandbox section.

## idmapped mounts vs uidmapshift

**Since LXCex moved to idmapped mounts, file permissions became more important.**
**With `uidmapshift` all container data was inaccessible from unprivileged user on the base system.**
**That's no longer the case with idmapped mounts because unprivileged users**
**across base system and containers have common ids.**

Make sure all subdirectories in `/var/lib/lxc` have minimal permissions and are not readable by `other` at least.
The same applies to the container data stored elsewhere.

However, for idmapped mounts to work, the minimal permissions must include directory traversal for others.
This could be worked around using `setfacl`, but that comlication overweights the convenience.

If all the above is a security concern, do not use idmapped mounts.

## Quirks

* Something smashes `/dev/ptmx` after a while.
* Under Weston, drop-down menus in Kate appear with a significant delay.
  Sympthoms look like those described in merge request 1123
* Weston terminal does not honour user's shell from /etc/passwd and uses `sh`
  if Weston is started by runit, where parent shell is `sh`.
* When maximizing Chromium, top left position sometimes remains unchanged.
* Copy-pasting from Kate to Weston terminal drops newlines.
  This might be a security precaution, but I'd like a dialog then. Same as in linuxmint.

## TODO

* get rid of hardcoded `lxcex`, let the user to customize that?
* find the best way to create /run/user/<uid> in containers
* automatic move network adapters to container (udev rule?)
* DHCP
* improve UX
* copy-paste across containers
* pipewire (video)
* LibreOffice complains /proc is not mounted. What, excuse me, fucking for?
  Even such a malware as modern web browsers does not need it.
  Given that it's mounted, indeed. With restrictions.

## Wishes (TODO list?)

* A decent panel for Sway.
* Disable window decoration in Weston's wayland backend, not only in headless.
* A decent replacement for runit.
* Weston and wlroots-based compositors close session when connection to the socket
  is lost. Need re-connect feature.


## Changeblog

### Nov 2, 2024

* Revised sharing at last. See updated Chapter 8.
* Moved to idmapped rootfs. Keeping `uidmapshift` around for now.
  As a replacement for `ls -l /var/lib/lxc` that showed ids of `uidmapshift`ed, containers,
  there's an `lxcex-idmap` script now that shows subordinate user ids for each container
  that use idmap.

### Oct 22, 2024

Okay, dropping a line here. I still seem to be a single user of all this shit and,
as my African friends say, "daz good!"

Lots of features wanted. Number one is to get rid of runit. Number two is UI utils.
All others wishes are just a little things.

### Mar 3, 2024

So far so good. New Chapter 8 is out.

### Feb 14, 2024

Three months since inception, and now I can say farewell, linuxmint.
LXCex is on all my laptops from now onwards.

Major updates:
* Bugfixes, of course.
* start-user-containers now detects running system compositor, so it's much easier to run GUI containers manually.
* dist-upgrade script
* chapter 7

### Jan 31, 2024

Yet another milestone: [makecex](https://github.com/amateur80lvl/lxcex/tree/main/makecex) is out!
This script generates bootable media.
Not excessively tested, it just works just for me.

### Jan 27, 2024

Packages repo is out. For now the only package there is uidmapshift.
Planning to add patched version of libpulse, thus getting rid of file permission fixer.

Although death from laugh is not my ultimate goal, I had to add signing key for me, anonymous.

Automation is on the way. Commenced after I managed to crash the system simply by remounting /var/lib/lxc with running containers.
Did not realize it's so dangerous.
This action destroyed all mounted partitions including backup USB stick which had nothing to do with that. Why???

### Jan 17, 2024

It plays music! Initial version of Chapter 6 is out, to be updated.

### Jan 16, 2024

XFCE desktop environment is working!

### Dec 30, 2023

Tag: 0.0.2
* Misc. tweaks.
* Made --no-install-recommends the default option, chapters 1-4 need testing.

### Dec 29, 2023

Initial commit and release.

## Tips and tricks

### Upgrading the system

You may wonder how to issue `apt upgrade` for a dozen of containers including the base system.
That's what
[dist-upgrade](https://github.com/amateur80lvl/lxcex/tree/main/base-system/root/dist-upgrade)
script is for.
It is based on
[lxcex-chroot](https://github.com/amateur80lvl/lxcex/tree/main/base-system/usr/local/bin/lxcex-chroot)
which runs arbitraty command, properly chrooting to the container's rootfs.

### Firefox

They lauched apt repository, so it's worth to follow
[their instructions](https://support.mozilla.org/en-US/kb/install-firefox-linux)

At the time of writing, firefox (version 123) uses wayland by default.
If you remember, WAYLAND_DISPLAY is reset in
[/home/user/.config/sv/xfce4/run](https://github.com/amateur80lvl/lxcex/tree/main/containers/xfce4/rootfs/home/user/.config/sv/xfce4/run)
and this makes firefox to enter infinite loop saying

`Warning: ConnectToCompositor() try again : Connection refused`

There are two options:
* add --display=:0.0 command line option
* set WAYLAND_DISPLAY when running firefox

I tried both. Initially I chose the latter, using a script:
```
#!/bin/sh

if [ -n "$X_WAYLAND_DISPLAY" ] ; then
    export WAYLAND_DISPLAY=$X_WAYLAND_DISPLAY
else
    # fallback
    export WAYLAND_DISPLAY=wayland-1
fi

firefox
```

However, this makes copy-paste troublesome so I returned to X mode for now.

### NFS + autofs

My initial setups were weird and fragile simply because of lack of understanding of shared subtrees.
* https://www.kernel.org/doc/html/latest/filesystems/sharedsubtree.html
* https://lwn.net/Articles/689856/

Here's the solution:
1. Make some mount point recursively shared. You can't make an arbitrary directory in the file system
   rshared (that was my point of misunderstanding), it should be an actual mount point,
   i.e. a directory where some filesystem is mounted.

   I want to use `/mnt/autofs` for autofs so let's mount a tmpfs there and rshare it:
   ```
   mkdir -p /mnt/autofs
   mount -t tmpfs -o size=64K --make-rshared tmpfs /mnt/autofs
   mkdir /mnt/autofs/myserver
   ```
2. Create autofs configuration:
   ```
   mkdir /etc/auto.maps
   echo "/mnt/autofs/myserver /etc/auto.maps/myserver" >/etc/auto.master.d/myserver.autofs
   echo "shared-dir myserver.example.com:/var/share/top-secret" >/etc/auto.maps/myserver
   ```
   and restart autofs.

3. Add the following line to the container's config:
   ```
   lxc.mount.entry = /mnt/autofs mnt/autofs none create=dir,rbind 0 0
   ```

Start the container. Inside, `ls /mnt/myserver/shared-dir` should work as expected.

However, user:group will be nobody:nogroup and I have no idea how to setup correct id mapping.


### Editing main menu

`menulibre` looks kinda bloatware and currently is totally broken in excalibur.
However, its quite easy to edit menus manually:
* All menu entries are listed in `.config/menus/xfce-applications.menu`
* Configuration files for each entry are in `.local/share/applications`

### Running programs as a different users

Containers are great to isolate workspaces as if they were running on separate machines.
This greatly simplifies such things as networking which are too error-prone
or impossible to maintain within a single system.

But at container level everything is still the same: single home directory where all
applications have full access to user's data.

This is dangerous.
Potentially, every program that use network may leak your sensitive data, even unintentially.

Basically, all programs that work with your data should be run in a container with
disabled networking, and probably I'll end up with such arrangement.

But for now I have a few legacy XFCE environments each running in its own container.
A temporary solution I deployed within those containers is restricted network access
for the main user and running all networking software as a different users.
This software includes Firefox, Chromium, Mullvad, and Tor browsers, plus Thunderbird.
Of course, some do support Wayland already but LXCex still has copy-pasting issues
and it's a blocking factor to run them natively.

Here's the setup, on the example of Firefox,
which can be used as a boilerplate for other programs.

First, create a separate user:
```
useradd -g users --skel /etc/skel --shell /bin/bash --create-home firefox
```
Then, move directories:
```
mkdir /home/firefox/.cache
mv /home/user/.mozilla /home/firefox/
mv /home/user/.cache/firefox /home/firefox/.cache/
chown -R firefox /home/firefox
```
Next, prepare a script `/usr/local/bin/start-firefox`:
```
#!/bin/sh

USER=firefox

if [ -z "$1" ] ; then
    xhost +SI:localuser:$USER
    exec sudo $0 dosu
elif [ "$1" = "dosu" ] ; then
    exec su -l -c "$0 run" $USER
elif [ "$1" = "run" ] ; then
    cd /home/$USER
    . /usr/local/share/lxcex-xdg.sh
    export DISPAY=:0.0
    exec firefox --display=:0.0
fi
```
Actually, `DISPLAY` environment variable is not necessary here, but this script
can be used as a boilerplate to run other apps so I intentionally left it.

Finally, create `/etc/sudoers.d/50-start-firefox` (alas, sudo is required):
```
user ALL = NOPASSWD: /usr/local/bin/start-firefox dosu
```
You may need to modify XFCE start menu entry.
And to add -P option for the first time, otherwise firefox may start with a blank profile.

It's a good idea to share `Downloads` directory.
Previous approach was a group-writeable directory with symlinks to it, but the best way is `lxces-share`.

Let `Downloads` direcroty be in `user`'s home directory, as it used to.
Then, create the following `sharetab` for the container:
```
/var/lib/lxc/<container-name>/rootfs/home/user/Downloads  firefox  /home/firefox/Downloads
```
And use hooks in container configuration, as shown in Chapter 8:
```
lxc.hook.pre-start = /usr/local/bin/lxcex-share
lxc.hook.mount     = /usr/local/bin/lxcex-share
lxc.hook.start     = /usr/local/bin/lxcex-share
lxc.hook.post-stop = /usr/local/bin/lxcex-share
```

## Miscellaneous notes

### links

* [Awesome Wayland: A curated list of Wayland code and resources.](https://github.com/natpen/awesome-wayland)
* [Sway wiki](https://github.com/swaywm/sway/wiki)
* [PipeWire Guide](https://github.com/mikeroyal/PipeWire-Guide)
* About [Xwayland](https://ofourdan.blogspot.com/2023/10/xwayland-rootful-part1.html). However, -geometry does not work for me.
* [Lumina](https://lumina-desktop.org/): sans-bloatware desktop environment
* [Hyperbola](https://www.hyperbola.info/): yet another amazing project with
  [strong philosophy](https://wiki.hyperbola.info/doku.php?id=en:philosophy:incompatible_packages&redirect=1)

### socket proxies

Discovered this article when wrote chapter 6:
https://discuss.linuxcontainers.org/t/audio-via-pulseaudio-inside-container/8768
They use LXD and it's worth to take a look at the implementation od socket proxies.
Can we use them to retain container socket and reconnect to the host socket when
the base compositor gets restarted? Or when a container resumes from hibernation?

### mount namespaces and shared subtrees

Again,
* https://www.kernel.org/doc/Documentation/filesystems/sharedsubtree.txt
* https://lwn.net/Articles/689856/

I didn't get why I had to
```bash
mount --make-shared /run
```
i.e. `/run`, not `/run/user` if I did `mount --rbind /run/user "${LXC_ROOTFS_MOUNT}/run/host/run/user"`
in containers and wanted all uid submounts to propagate.

After re-reading that a few times it should be clear, eventually.

### smartd tweaks

`smartd` is the most reliable tool to disable HDD spindowns thus far:
1. edit `/etc/default/smartmontools`:
   ```
   smartd_opts="--interval=10 --attributelog=- --savestate=-"
   ```
   Key option is `--interval`, others disable saving state which I never needed.
2. Make sure `-n` option is `never` in `etc/smartd.conf`, i.e.:
   ```
   DEVICESCAN -d removable -n never -m root -M exec /usr/share/smartmontools/smartd-runner
   ```

### More packages

My extra packages, just for the record.

* Fonts: `gnome-font-viewer`, looks unnecessary
* Images: `gthumb`
* Kate: when installed in XFCE, it needs some theme. I used `breeze-icon-theme`.
* KDE `systemsettings`: installed just in case, zero profit so far.
* Ungoogled chromium needs: `libnss3`, `libasound2`
