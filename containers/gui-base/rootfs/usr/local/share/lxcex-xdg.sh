# Include file for both bash profile and runit

# XXX all this should be managed by a PAM module?

create_xdg_runtime_dir()
{
    uid=$1

    XDG_RUNTIME_DIR=/run/user/$uid
    mkdir -p -m 700 "${XDG_RUNTIME_DIR}"
    chown $uid "${XDG_RUNTIME_DIR}"

    if [ -n "$HOST_XDG_RUNTIME_DIR" ] ; then
        # Create links to host's sockets.

        # Wayland
        if [ -n "$HOST_WAYLAND_DISPLAY" ] ; then
            ln -sf "../../host${HOST_XDG_RUNTIME_DIR}/${HOST_WAYLAND_DISPLAY}" "${XDG_RUNTIME_DIR}"
        fi

        # Pipewire
        if [ -z "${HOST_PIPEWIRE_REMOTE}" ] ; then
            HOST_PIPEWIRE_REMOTE=pipewire-0
        fi
        ln -sf "../../host${HOST_XDG_RUNTIME_DIR}/${HOST_PIPEWIRE_REMOTE}" "${XDG_RUNTIME_DIR}"

        # Pulseaudio
        mkdir -p -m 700 "${XDG_RUNTIME_DIR}/pulse"
        chown $uid "${XDG_RUNTIME_DIR}/pulse"
        ln -sf "../../../host${HOST_XDG_RUNTIME_DIR}/pulse/native" "${XDG_RUNTIME_DIR}/pulse/"
    fi
}

if [ ! -f /run/host/xdg.env ] ; then
    echo "WARNING: no XDG environment provided by host"
else
    . /run/host/xdg.env

    if [ -z "$HOST_XDG_RUNTIME_DIR" ] ; then
        echo "WARNING: HOST_XDG_RUNTIME_DIR is not provided"
    fi

    if [ -z "$HOST_WAYLAND_DISPLAY" ] ; then
        echo "WARNING: HOST_WAYLAND_DISPLAY is not provided"
    fi

    if [ `id -u` = "0" ] ; then
        # we're root
        # create XDG_RUNTIME_DIR for each user belonging to `users` group
        # XXX obtain from groups file
        users_gid="100"
        for home in /home/* ; do
            home=`readlink -f "$home"`
            [ -d "$home" ] || continue
            [ `stat -c %g "$home"` = "$users_gid" ] || continue
            username=`basename "$home"`
            uid=`id -u "$username"`
            [ -n "$uid" ] || continue

            create_xdg_runtime_dir $uid
        done
    fi

    export XDG_RUNTIME_DIR=/run/user/`id -u "$USER"`
    export WAYLAND_DISPLAY="${HOST_WAYLAND_DISPLAY}"

    unset HOST_XDG_RUNTIME_DIR
    unset HOST_WAYLAND_DISPLAY
    unset HOST_PIPEWIRE_REMOTE
fi
