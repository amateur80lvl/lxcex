# Chapter 6.
# Pipewire

Install the following packages on the base system:
```bash
apt install rtkit pipewire-audio pipewire-libcamera \
libcamera-ipa pulseaudio-utils pavucontrol inotify-tools runit
```
Add the user to audio, video, and pipewire groups.

Services should be started in the following order:

1. pipewire
2. wireplumber
3. pipewire-pulse

Let's use `runit` to manage them. As user, create the following files:
* [sv/pipewire/run](https://github.com/amateur80lvl/lxcex/tree/main/base-system/home/user/sv/pipewire/run)
* [sv/wireplumber/run](https://github.com/amateur80lvl/lxcex/tree/main/base-system/home/user/sv/wireplumber/run)
* [sv/pipewire-pulse/run](https://github.com/amateur80lvl/lxcex/tree/main/base-system/home/user/sv/pipewire-pulse/run)

Make `run` files executable and create symlinks:
```bash
for s in pipewire wireplumber pulse ; do
    chmod +x sv/$s/run
    ln ../sv/$s service/
done
```
Now, replace the line
```bash
exec sway
```
in `.profile` with:
```bash
exec /usr/bin/dbus-run-session -- /usr/local/bin/sway-session
```
Let's create [/usr/local/bin/sway-session](https://github.com/amateur80lvl/lxcex/tree/main/base-system/usr/local/bin/sway-session):
```bash
#!/bin/sh

/usr/bin/runsvdir /home/$USER/service &
runit_pid=$?

/usr/bin/sway

kill -HUP $runit_pid
wait $runit_pid
```
So, we start pipewire services in background and run Sway.
All this is executed under control of `dbus-run-session` that
creates session bus and sets all necessary environment variables
for its child process. Weird scheme, but we have no better choice.

Let's test. First, `wpctl status` should display devices, sinks, and sources.
Second, let's play something:
```bash
wget https://upload.wikimedia.org/wikipedia/commons/transcoded/3/3b/En-us-ASCII.ogg/En-us-ASCII.ogg.mp3
pw-play En-us-ASCII.ogg.mp3
```
Do you hear that? If you do, let's continue.

## Configuring containers

Same as for Wayland, the minimalistic approach to make pipewire working in containers
is to share its host socket `/run/user/<uid>/pipewire-0`. Amended scripts:
* [/usr/local/bin/start-user-containers](https://github.com/amateur80lvl/lxcex/tree/main/base-system/usr/local/bin/start-user-containers):
  added `HOST_PIPEWIRE_REMOTE`. Just to hardcode default value
  in a single place https://docs.pipewire.org/page_module_protocol_native.html
* [xdg-runtime-dir.start-host](https://github.com/amateur80lvl/lxcex/tree/main/containers/gui-base/xdg-runtime-dir.start-host):
  added permissions setting for pipewire and pulseaudio sockets
* [xdg-runtime-dir.mount](https://github.com/amateur80lvl/lxcex/tree/main/containers/gui-base/xdg-runtime-dir.mount):
  simplified a bit.
* [/usr/local/share/lxcex-xdg.sh](https://github.com/amateur80lvl/lxcex/tree/main/containers/gui-base/rootfs/usr/local/share/lxcex-xdg.sh):
  create links to pipewire and pulseaudio sockets.

All above was pretty simple to do, but one thing stole half of my day:
permissions on `/run/user/<uid>/pulse` directory on the host were magically
reset to 700 after container was started. I checked everything,
I `strace`d lxc-start with entire subprocesses. No luck.
Finally, I noticed that permissions were reset when waybar was restarted.
I used a slow old machine for testing where rendering delays were noticeable.
Waybar was restarted because I restarted my containers with meta-shift-c
-- that reloaded Sway config. I checked waybar code and this led me to libpulse.
That's who reset those permissions and this happened when waybar's
pulseaudio module opened the socket!

As a workaround I made a fixer service:
[sv/pulse-fixer/run](https://github.com/amateur80lvl/lxcex/tree/main/base-system/home/user/sv/pulse-fixer/run).
Add it to user services on the base system.

Basically, everything should work seamlessly in containers.
You can test sound with `pw-play` from pipewire package,
you can give `pavucontrol` a try, and XFCE should correctly display
its pulseaudio volume control.
