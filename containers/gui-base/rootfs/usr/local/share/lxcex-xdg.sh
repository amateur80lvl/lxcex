# Include file for both bash profile and runit
# All this should be managed by a PAM module?

if [ -z "$HOST_XDG_RUNTIME_DIR" ] ; then
    # some default value
    HOST_XDG_RUNTIME_DIR=/run/user/1000
fi

# Create /run/user/<uid> directory and make links to host socket.
if [ -z "${HOST_WAYLAND_DISPLAY}" ] ; then
    # some default value
    HOST_WAYLAND_DISPLAY=wayland-1
fi

export WAYLAND_DISPLAY=${HOST_WAYLAND_DISPLAY}
export XDG_RUNTIME_DIR=/run/user/`id -u $USER`
mkdir -p "${XDG_RUNTIME_DIR}"
chown $USER "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"
ln -s "../../host-xdg-runtime-dir/${HOST_WAYLAND_DISPLAY}" "${XDG_RUNTIME_DIR}"
