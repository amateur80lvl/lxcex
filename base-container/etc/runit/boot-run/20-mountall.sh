# Based on /etc/init.d/mountall.sh and /etc/init.d/mountdevsubfs.sh

do_mount_all()
{
    . /lib/init/vars.sh
    . /lib/init/tmpfs.sh
    . /lib/init/mount-functions.sh

    TTYGRP=5
    TTYMODE=620
    [ -f /etc/default/devpts ] && . /etc/default/devpts

    MNTMODE=mount_noupdate

    mount -a  # mount everything from /etc/fstab

    mount_run $MNTMODE
    mount_lock $MNTMODE
    mount_shm $MNTMODE

    if [ ! -d /dev/pts ] ; then
        mkdir --mode=755 /dev/pts
        [ -x /sbin/restorecon ] && /sbin/restorecon /dev/pts
    fi
    domount "$MNTMODE" devpts "" /dev/pts devpts "-onoexec,nosuid,gid=$TTYGRP,mode=$TTYMODE"
}

do_mount_all
