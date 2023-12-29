# Mount tmpfs on /run and/or /run/lock

do_mount_run()
{
    . /lib/init/vars.sh
    . /lib/init/tmpfs.sh
    . /lib/init/mount-functions.sh

    mode=mount_noupdate

    mount_run $mode
    mount_lock $mode
}

do_mount_run
