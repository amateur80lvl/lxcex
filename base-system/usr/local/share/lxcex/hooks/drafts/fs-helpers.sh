clobber_fs_entry()
{
    if [ -h "$1" ] ; then
        # don't clobber symbolic links
        return
    fi
    if [ -d "$1" ] ; then
        mount -t tmpfs -o size=0 tmpfs "$1"
    else
        mount --bind /dev/null "$1"
    fi
}

in_list()
{
    for n in $2 ; do
        if [ $1 = $n ] ; then
            return 0
        fi
    done
    return 1
}

clobber()
{
    dir="$1"
    exclude="$2"
    if [ ! -d "${dir}" ] ; then
        return
    fi
    for entry in "${dir}"/* ; do
        name=`basename "${entry}"`
        if in_list "${name}" "${exclude}" ; then
            continue
        fi
        clobber_fs_entry "${entry}"
    done
}
