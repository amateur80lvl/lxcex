# LXCex

Lightweight security-focused desktop operating system based on Devuan and LXC.
Yet another attempt to make an alternative to [Qubes OS](https://www.qubes-os.org/).
This is not a distro, this is an instruction and a set of files and patches,
similar to [LFS](https://www.linuxfromscratch.org/).

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
I swear I'll get rid of them as soon as the number of users go beyond 1.5.
But in general, the rationale is as follows:

## Rationale

* keep attack surface and fingerprinting surface as small as possible
* make [plausible deniability](https://github.com/amateur80lvl/pdt) easy

## Quirks

* Drop-down menus in Kate have significant offset to the right:
 * fixed after playing with systemsettings, need to reproduce
 * appear with a significant delay
  * sympthoms look like those described in merge request 1123
 * XFCE apps, e.g. Thunar, don't have such quirks. -- because of XWayland?
* Weston terminal does not honour user's shell from /etc/passwd and uses `sh`
  if Weston is started by runit, where parent shell is `sh`.
* When maximizing Chromium, top left position sometimes remains unchanged.
* Copy-pasting from Kate to Weston terminal drops newlines.

## TODO

* improve UX
* copy-paste across containers
* fix keypad when numlock is off (disease of most distros I know)
* shared folders
* pipewire
* dbus in containers
* composefs, when kernel 6.6 gets in stable release

## Wishes (TODO list?)

* A decent panel for Sway.
* Disable window decoration in Weston's wayland backend, not only in headless.
* A decent replacement for runit.
* Stand-alone Kate fork. Its debian package pulls a lot of dependencies.
  Probably I simply should compile it by myself.
* Weston and wlroots-based compositors close session when connection to the socket
  is lost. Need re-connect feature.


## The book

* [Chapter 1. Installing the base system with debootstrap](https://github.com/amateur80lvl/lxcex/tree/main/book/ch1-installing-base-system.md)
* [Chapter 2. The basic networking](https://github.com/amateur80lvl/lxcex/tree/main/book/ch2-basic-networking.md)
* [Chapter 3. LXC and the base container](https://github.com/amateur80lvl/lxcex/tree/main/book/ch3-lxc-and-base-container.md)
* [Chapter 4. Networking](https://github.com/amateur80lvl/lxcex/tree/main/book/ch4-networking.md)
* [Chapter 5. Desktop Environment](https://github.com/amateur80lvl/lxcex/tree/main/book/ch5-desktop-environment.md)
* [Chapter 6. Pipewire](https://github.com/amateur80lvl/lxcex/tree/main/book/ch6-pipewire.md)


## Changelog

### Jan 16, 2024

XFCE desktop environment is working!

### Dec 30, 2023

Tag: 0.0.2
* Misc. tweaks.
* Made --no-install-recommends the default option, chapters 1-4 need testing.

### Dec 29, 2023

Initial commit and release.


## Miscellaneous notes

### links

* [Awesome Wayland: A curated list of Wayland code and resources.](https://github.com/natpen/awesome-wayland)
* [Sway wiki](https://github.com/swaywm/sway/wiki)
* [PipeWire Guide](https://github.com/mikeroyal/PipeWire-Guide)

### socket proxies

Discovered this article when wrote chapter 6:
https://discuss.linuxcontainers.org/t/audio-via-pulseaudio-inside-container/8768
They use LXD and it's worth to take a look at the implementation od socket proxies.
Can we use them to retain container socket and reconnect to the host socket when
the base compositor gets restarted? Or when a container resumes from hibernation?

### mount namespaces and shared subtrees

* https://lwn.net/Articles/689856/
* https://www.kernel.org/doc/Documentation/filesystems/sharedsubtree.txt

Still don't get why I have to
```bash
mount --make-shared /run
```
i.e. `/run`, not `/run/user` if I `mount --rbind /run/user "${LXC_ROOTFS_MOUNT}/run/host/run/user"`
in containers and want all uid submounts to propagate.

### From which deb package is this file?

`dpkg -S /path/to/file`

### How to examine the content of a deb file

Let it be base-files:
```
apt download base-files
mkdir base-files
dpkg-deb -R base-files*.deb base-files
```
