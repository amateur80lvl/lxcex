# Chapter 5.
# Desktop environment

It would be cool to run desktop environment in a separate container
and I even tried that but I quickly found it's not quite possible.
Even Qubes OS runs its X server in the Dom0, I don't think I have enough
skills and/or time to elaborate a better solution.

Desktop environment depends on three major components:
`udev`, `dbus`, and `elogind`. It's quite difficult to run the former
twos in a container because they are tightly bound to the base system.

Although `elogind` is not a pure Unix way, and in Devuan you can
replace it with `consolekit` and `pam-ck-connector`, not all
compositors may honor that in terms of package dependencies.
Sway will, but for my experiments I chose `elogind`.

The core of our desktop environment is Wayland.
It's up to you which compositor to use for the base system,
I chose Sway as a simple and lightweight solution.
Basically, what you'll need from the base system's compositor
is switching between nested compositors.

For containers I use Weston and Cage. Weston is not perfect in terms of UX,
but it has an unique feature which I haven't found is other compositors so far:
`--width` and `--height` command line options.
They are invaluable if you want to fool fingerprinting in web browsers.


## Sway as the base system compositor

Strictly speaking, our minimalistic system won't have a system compositor
[in terms of Wayland](https://wayland.freedesktop.org/docs/html/ch02.html#sect-Compositors-System-Compositor).
As I can see, the idea with system compositor did not go, and I'm too lazy
to check things in distros I'm not a fan of. Correct me if I'm wrong, please,
but I'm still see VTs everywhere with no attempts to replace them, although
[some were taken](https://dvdhrm.wordpress.com/2013/07/08/thoughts-on-linux-system-compositors/)
yet 10 years ago!

So we'll simply run Sway under unprivileged user. Let's install it:
```bash
apt install sway bemenu waybar fonts-font-awesome foot wev
```
Notes on packages:
* `waybar`: slightly better than the default swaybar.
   However it sucks not much less and needs a replacement (TBD).
  `fonts-font-awesome` is necessary to display icons.
* `bemenu`: application launcher
* `foot`: terminal application
* `wev` could be useful to discover key codes

You also may need `sway-backgrounds`. Sway does not have a strict dependency, nevertheless,
its default configuration refers to a file from that package.
Personally, I don't use backgrounds, so I don't install it.

Let's create a user in the base system for running Sway. Let it be just `user`:
```bash
adduser --ingroup users --shell /bin/bash user
```
Note that this command will update `/etc/subuid` and `/etc/subgid` and I don't know
how to disable this. I suggest to drop `user:` line from both files.

Here is my [configuration file for Sway](https://github.com/amateur80lvl/lxcex/tree/main/base-system/home/user/.config/sway/config).
It 's a restructured version of the original `/etc/sway/config` with the following major changes:
* All key binbgings are grouped together and compacted. Most important bindings come first,
  to make it easy to print and hang them as a cheatsheet on the wall.
* Added `--to-code` for letter keys to make such keybingings working when non-English keyboard layout is active.
* Disabled XWayland for security reasons. Although, it's okay to run XWayland in nested compositors.
* Disabled running anything from `/etc/sway/config.d`. The only `50-systemd-user.conf`
  in it is irrelevant for Devuan.

This line
```
exec_always sudo /usr/local/bin/start-user-containers gui-base
```
in the beginning of Sway configuration file starts user's containers.
We don't have any yet, so comment it out for now.

## Login manager

TBD. I have no idea which is the best one for minimalistic system.
I do without any.
Let's add the following lines to the end of `/home/user/.profile`:
```bash
# if logged in from console
if [ x"$TERM" = "xlinux" ] ; then
    exec sway
fi
```

Now, check if Sway is running if you login from console and proceed to the next section.

## Setting up the basic GUI container

Let's create a basic GUI container:
```bash
lxc-copy -n base -N gui-base
```

Don't start it, just chroot:
```bash
chroot /var/lib/lxc/gui-base/rootfs
```
and install a few more packages:
```bash
apt install weston cage xwayland mesa-utils
```
Notes on packages:
* `cage`: to run single apps
* `xwayland`: for running X Window apps
* `mesa-utils`: for glxgears demo

Unlike the `base` container, we'll make `gui-base` unprivileged by adding:
```
lxc.include = /usr/share/lxc/config/devuan.userns.conf
lxc.idmap = u 0 200000 65536
lxc.idmap = g 0 200000 65536
```
to `/var/lib/lxc/gui-base/config` and shifting user and group ids.
Make sure both `/etc/subuid` and `/etc/subgid` contain
```
root:200000:65536
```
and run this command:
```bash
uidmapshift -b /var/lib/lxc/gui-base 0 200000 65536
```

Let's also add some network configuration to `/var/lib/lxc/gui-base/config`:
```
lxc.net.0.type = veth
lxc.net.0.name = ethv
lxc.net.0.link = br0
lxc.net.0.flags = up
lxc.net.0.hwaddr = 00:16:d3:6f:63:1a
lxc.net.0.ipv4.address = 10.0.0.3/24
```
plus these directives (you may need to fix `/usr/share/lxcfs/lxc.mount.hook`,
see [procfs and sysfs section in Chapter 3](ch3-lxc-and-base-container.md#procfs-and-sysfs):
```
lxc.mount.auto =
lxc.mount.hook = /var/lib/lxc/gui-base/restricted-proc.mount
```
Mounting `/proc` with the mount hook is necessary to make `dbus` working.
We could do that with `lxc.mount.auto = proc:mixed`, but this would be less secure.

Now we're ready to test the container:
```bash
lxc-start gui-base
```

Started with no errors? That's good, let's create a user in it:
```bash
lxc-attach gui-base -- adduser --ingroup users --shell /bin/bash user
```


## Nesting compositors

The bare minimum for running a nested compositor is to give access to parent's socket.
But you can't simply command Wayland "Use that socket".
You have to deal with `XDG_RUNTIME_DIR` and `WAYLAND_DISPLAY`
environment variables.
And, to add insult to injury, you can't `mount --bind` a socket.
You can mount everything but sockets.
The nice idea "everything is a file" simply breaks against them.

You'll have to mount the entire host's `XDG_RUNTIME_DIR`
somewhere in the container and symlink socket to user's runtime directory:
```
+-------------------+  +---------------------------------+
| Host              |  | Container                       |
|                   |  |                                 |
| Sway           mount --bind                            |
| /run/user/1000 ------------> /run/host-xdg-runtime-dir |
|    wayland-1      |  |         wayland-1   <----+      |
|    wayland-1.lock |  |                          |      |
|    sway-ipc...    |  | /run/user/1000   symlink |      |
|    ...            |  |    wayland-1 ------------+      |
+-------------------+  +---------------------------------+
```
[xdg-runtime-dir.mount](https://github.com/amateur80lvl/lxcex/tree/main/containers/gui-base/xdg-runtime-dir.mount)
script can be used as a mount hook to mount `/run/host-xdg-runtime-dir`
in the container. Add it to the container config:
```
lxc.hook.mount = /var/lib/lxc/gui-base/xdg-runtime-dir.mount
```
Basically, we could use `lxc.mount.entry` for that purpose, but the hook
is better because it does without hardcoded user ids and paths.
Except `/run/host-xdg-runtime-dir` of course, but that's a static thing.

To make socket accessible from container, the following permissions
could be set on the host:
```bash
seftacl -m 201000:--x /run/user/1000
setfacl -m 201000:rw- /run/user/1000/wayland-1
```
where 201000 is container's user id on the host system, given that container's subuid is 200000.

`--x` on `/run/user/1000` is a pass-through permission to disable reading directory content.
This means `ls /run/host-xdg-runtime-dir` will fail, but the socket will be accessible
as long as we've granted `rw-` permissions on it.

However, a better way is to grant permissions to a whole group `users`.
There are a couple of hooks:
* [xdg-runtime-dir.start-host](https://github.com/amateur80lvl/lxcex/tree/main/containers/gui-base/xdg-runtime-dir.start-host)
  grants permissions when container starts, and
* [xdg-runtime-dir.stop](https://github.com/amateur80lvl/lxcex/tree/main/containers/gui-base/xdg-runtime-dir.stop)
  revokes permissions when it stops.

Group id is provided as a parameter to hooks in the configuration:
```
lxc.hook.start-host = /var/lib/lxc/gui-base/xdg-runtime-dir.start-host 200100
lxc.hook.stop = /var/lib/lxc/gui-base/xdg-runtime-dir.stop 200100
```
i.e. 200100 is container's subordinate gid 200000 plus 100 which corresponds `users`
group. That's why we specified `--ingroup users` above.

When all the above is done, we can try nested compositors. Restart the container and run:
```bash
XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 \
lxc-attach -n gui-base -u 1000 -g 100 -- weston -Swayland2
```
or
```bash
XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 \
lxc-attach -n gui-base -u 1000 -g 100 -- cage glxgears
```


## Direct Rendering

With the minimal configuration described in previous section, compositors will use
software rendering backend. To enable DRI in containers,
a couple of tweaks is required.

First, you should make `/dev/dri/renderD128` accessible from the container.
Add the following lines to container's config:
```
lxc.cgroup.devices.allow = c 226:128 rwm
lxc.mount.entry = /dev/dri/renderD128 dev/dri/renderD128 none bind,create=file 0 0
```
and give permission on it:
```bash
setfacl -m 201000 /dev/dri/renderD128
```

Second, a device entry that provides DRM should be accessible in container's `/sys`.
This entry can be found by reading `/sys/class/drm/renderD128` or `/sys/dev/char/226:128` symlink
and stripping off two last components, i.e. on x86-64 system the link could be:
```
/sys/dev/char/226:128 -> ../../devices/pci0000:00/0000:00:02.0/drm/renderD128
```
and device entry is `/sys/devices/pci0000:00/0000:00:02.0`;
on Allwinner H6 boards this may look like this:
```
/sys/dev/char/226:128 -> ../../devices/platform/soc/1800000.gpu/drm/renderD128
```
so device entry will be `/sys/devices/platform/soc/1800000.gpu`

Note that `/sys/dev/char/226:128` symlink must exist in the container,
but `/sys/class/drm/renderD128` is not necessary.

The following hooks grant and revoke permissions on `/dev/dri/renderD128`
to `users` group, similar to xdg-runtime-dir above:
* [enable-dri.start-host](https://github.com/amateur80lvl/lxcex/tree/main/containers/gui-base/enable-dri.start-host)
* [enable-dri.stop](https://github.com/amateur80lvl/lxcex/tree/main/containers/gui-base/enable-dri.stop)

Configuration parameters:
```
lxc.hook.start-host = /var/lib/lxc/gui-base/enable-dri.start-host 200100
lxc.hook.stop = /var/lib/lxc/gui-base/enable-dri.stop 200100
```

If you don't mount `sysfs` in container, and this is very sensible
approach for security reasons, you'll need to add
[enable-dri.mount](https://github.com/amateur80lvl/lxcex/tree/main/containers/gui-base/enable-dri.mount)
mount hook to container's config:
```
lxc.hook.mount = /var/lib/lxc/gui-base/enable-dri.mount
```
which does all the job to share DRI entries from `/sys`.


Restart the container and run
```bash
XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 \
lxc-attach -n gui-base -u 1000 -g 100 -- cage glxgears
```
If everything is done correctly, you should see increased FPS rate at least.


## Desktop integration

A way to do this:
1. User logs in
2. Sway gets started
3. `/usr/local/bin/start-user-containers` is executed
4. Containers gets started
5. User services in containers get started and nested compositors get displayed in Sway

Where and how to manage user runtime directories and set environment variables is TBD.
Normally this is performed by `libpam-elogind`, but when we start an app with `lxc-attach`,
PAM is not honored. Besides, `libpam-elogind` deletes runtime directory on session end,
i.e. when you exit `su user`. Also, if we used PAM we'd have to create links by a custom script.
There's `libpam-script` package, but its configuration is weird and default priorities is not what
we need, i.e. scripts start when `/run/user/<uid>` does not exist yet.

For now, runtime directories and links are created by runit script
[/etc/sv/runsvdir-user/run](https://github.com/amateur80lvl/lxcex/tree/main/containers/gui-base/rootfs/etc/sv/runsvdir-user/run).
It's not a nice solution either.

For interactive sessions I suggest adding `XDG_RUNTIME_DIR` and `WAYLAND_DISPLAY`
environment variables to `.bashrc`.
This means `WAYLAND_DISPLAY` will be hardcoded. Normally we should take it from the base system
and pass to the container. There's a configuration directive `lxc.environment`
which looks perfectly suited for that, but unlike shells, if the variable does not exist,
all `lxc-*` commands will fail to process the configuration.
You can re-compile and re-package LXC with a patch [from here](https://github.com/lxc/lxc/issues/4385).
Here we go. Good luck.

### base system

Create file
[/etc/sudoers.d/50-start-user-containers](https://github.com/amateur80lvl/lxcex/tree/main/base-system/etc/sudoers.d/50-start-user-containers):
```
Defaults!/usr/local/bin/start-user-containers env_keep+="XDG_* WAYLAND_*"
Defaults:user env_keep+="XDG_* WAYLAND_*"

user ALL = NOPASSWD: /usr/local/bin/start-user-containers gui-base
```

Uncomment this line in `~/.config/sway/config`:
```
exec_always sudo /usr/local/bin/start-user-containers gui-base
```

Make sure
[/usr/local/bin/start-user-containers](https://github.com/amateur80lvl/lxcex/tree/main/base-system/usr/local/bin/start-user-containers)
exists.

### container

As root, create [user service](https://docs.voidlinux.org/config/services/user-services.html):
```bash
mkdir /etc/sv/runsvdir-user
```
Create [/etc/sv/runsvdir-user/run](https://github.com/amateur80lvl/lxcex/tree/main/containers/gui-base/rootfs/etc/sv/runsvdir-user/run).

Then,
```bash
su user
cd
```
and create sample Weston service:
```bash
mkdir -p sv/weston
```
[sv/weston/run](https://github.com/amateur80lvl/lxcex/tree/main/containers/gui-base/rootfs/home/user/sv/weston/run):
```bash
#!/usr/bin/env /lib/runit/invoke-run

exec 2>&1

if [ -e /etc/runit/verbose ]; then
    echo "invoke-run: starting ${PWD##*/}"
fi

export XDG_SESSION_ID=2

exec /usr/bin/weston -Swayland-2 --width 1280 --height 720
```
make it executable and symlink the service to `~/services`:
```bash
chmod +x sv/sv/run
mkdir service
ln -s ../sv/weston service
```

Now stop the container
```bash
lxc-stop gui-base
```
and press logo key+shift+c to reload Sway configuration.
If everything is done correctly, Weston should start.

Finally, I recommend to disable weston service by unlinking
`/home/user/service/weston`.
It's just an example and could be annoying
because `gui-base` is not a container for work,
it's just the base for others.


## XFCE

Let's install XFCE in a cloned `gui-base` container:
```bash
lxc-copy -n gui-base -N xfce
lxc-start xfce
lxc-attach xfce
apt install xfce4 atk-spi2-core
```
Notes on packages:
* `atk-spi2-core`: this package doesn't contain too much harm
  but makes XFCE a little bit happier.

XFCE does not support Wayland yet, but GTK will try using Wayland compositor
first when WAYLAND_DISPLAY is set. So if you try
```bash
su user
cage startxfce4
```
you'll see a blank screen.
Besides, `xfwm4` will complain that another window manager (it's `cage`)
is already running.

You'll have to start Xwayland manually:
```bash
Xwayland :0 &
WAYLAND_DISPLAY= DISPLAY=:0 startxfce4
```

You may want to adjust height with `-geometry` option (not supported in
Xwayland version shipped with Devuan Daedalus)
or simply switch to full screen in Sway.

If you want to start XFCE when container starts, create the following files:
* [/home/user/sv/xwayland/run](https://github.com/amateur80lvl/lxcex/tree/main/containers/xfce/rootfs/home/user/sv/xwayland/run):
* [/home/user/sv/xfce4/run](https://github.com/amateur80lvl/lxcex/tree/main/containers/xfce/rootfs/home/user/sv/xfce/run):

and create links:
```bash
ln -s ../sv/xwayland /home/user/service
ln -s ../sv/xfce4 /home/user/service
```
