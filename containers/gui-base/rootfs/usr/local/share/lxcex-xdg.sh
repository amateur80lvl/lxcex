# Include file for both bash profile and runit

if [ ! -f /run/host/xdg.env ] ; then
    echo "WARNING: no XDG environment provided by host"
else
    . /run/host/xdg.env

    if [ -z "$HOST_XDG_RUNTIME_DIR" ] ; then
        echo "ERROR: HOST_XDG_RUNTIME_DIR is not provided"
    elif [ -z "$HOST_WAYLAND_DISPLAY" ] ; then
        echo "ERROR: HOST_WAYLAND_DISPLAY is not provided"
    else
        # XXX all this should be managed by a PAM module?
        export WAYLAND_DISPLAY=${HOST_WAYLAND_DISPLAY}
        export XDG_RUNTIME_DIR=/run/user/`id -u $USER`
        mkdir -p "${XDG_RUNTIME_DIR}"
        chown $USER "${XDG_RUNTIME_DIR}"
        chmod 700 "${XDG_RUNTIME_DIR}"
        ln -sf "../../host${HOST_XDG_RUNTIME_DIR}/${HOST_WAYLAND_DISPLAY}" "${XDG_RUNTIME_DIR}"
    fi
    unset HOST_XDG_RUNTIME_DIR
    unset HOST_WAYLAND_DISPLAY
fi
