# Include file for both bash profile and runit

if [ ! -f /run/host/xdg.env ] ; then
    echo "WARNING: no XDG environment provided by host"
else
    . /run/host/xdg.env

    # XXX all this should be managed by a PAM module?

    # Create XDG_RUNTIME_DIR
    export XDG_RUNTIME_DIR=/run/user/`id -u $USER`
    mkdir -p -m 700 "${XDG_RUNTIME_DIR}"
    chown $USER "${XDG_RUNTIME_DIR}"

    if [ -z "$HOST_XDG_RUNTIME_DIR" ] ; then
        echo "WARNING: HOST_XDG_RUNTIME_DIR is not provided"
    else
        # Create links to host's sockets.

        # Wayland
        if [ -z "$HOST_WAYLAND_DISPLAY" ] ; then
            echo "WARNING: HOST_WAYLAND_DISPLAY is not provided"
        else
            export WAYLAND_DISPLAY=${HOST_WAYLAND_DISPLAY}
            ln -sf "../../host${HOST_XDG_RUNTIME_DIR}/${HOST_WAYLAND_DISPLAY}" "${XDG_RUNTIME_DIR}"
        fi

        # Pipewire
        if [ -z "${HOST_PIPEWIRE_REMOTE}" ] ; then
            HOST_PIPEWIRE_REMOTE=pipewire-0
        fi
        ln -sf "../../host${HOST_XDG_RUNTIME_DIR}/${HOST_PIPEWIRE_REMOTE}" "${XDG_RUNTIME_DIR}"

        # Pulseaudio
        mkdir -p -m 700 "${XDG_RUNTIME_DIR}/pulse"
        chown $USER "${XDG_RUNTIME_DIR}/pulse"
        ln -sf "../../../host${HOST_XDG_RUNTIME_DIR}/pulse/native" "${XDG_RUNTIME_DIR}/pulse/"
    fi
    unset HOST_XDG_RUNTIME_DIR
    unset HOST_WAYLAND_DISPLAY
    unset HOST_PIPEWIRE_REMOTE
fi
