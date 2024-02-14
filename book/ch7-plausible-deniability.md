# Chapter 7.
# Plausible Deniability

You surely know what plausible deniability means. In terms of LXCex it's when your system looks innocent after boot,
but then, if necessary, it can be turned into a true combat unit.

All distros are made without privacy in mind. Well, you may argue Qubes or Tails are special.
No. Without full disk encryption they are in the same row because full disk encryption is not deniable.

So, in a typical distro it's damn hard to implement privacy. Any piece of ~~shit~~ the system
(`ucf`, for example) can expose your intentions.

With LXC containers things are much easier. Your base system is always clean and everything you want to
hide is inside containers on a secret volume.

You might already notice I referred to my [toolkit](https://github.com/amateur80lvl/pdt) which has no instructions.
Actually, there's an article I wrote somewhere, but you better don't waste you time trying to find and read it.
It's obsolete, but the basic idea is still the same and can be expressed in one sentence:

```
Use cryptsetup on top of losetup.
```

With `losetup` you can create a device even on a mounted volume. You should use unallocated blocks,
if you don't want to damage your cover filesystem.

I can't share my solution for ext4 yet, it's built around a custom device instead of loop and needs a kernel driver.
But for now you can use FAT filesystem as a cover. FAT has the simplest allocation strategy and you can create a loop device
from the last allocated cluster + some reserved space up to the end of disk or partition.

## Deniability

In any scheme, there are always red flags for criminals which will torture you. Your deniability will sound childish
if they find such tools, as shufflecake, or any other custom kernel driver in your system.
The best solution is not to keep any cryptographic tools, and even not to install them. Including `cryptsetup`.
Configure ssh entry and bootstrap the system remotely, from an offshore system.
Over ssh you can setup a tmpfs volume and then upload and run all you need.

I won't propose any security scheme, I'll focus on LXCex-specific aspects only.
You should think through your own by yourself and analyse all risks.
Be creative. Be smart.

## Red flags

You should not leave any traces. This requires the folowing minimal precautions which can be treated as red flags:

* `/var/log` and `/tmp` on a tmpfs. Deniable as an SSD wearing avoidance.
* Disabled TRIM on the cover filesystem. With TRIM enabled, your hidden volume will be destroyed, so you have to.
  This is plausibly deniable for spinning disks, consider using them instead of SSD.
* High entropy in unused sectors. Deniable, but... still a red flag.
* No swap. Deniable as an SSD wearing avoidance. BTW does anyone still use swap?
  If you do, consider using a file on your hidden volume. Buying RAM is a better option.

Mind bash history and type
```
HISTFILE=
```
before bootstrapping your combat system.

## Bootstrapping

One possible implementation could be as follows. It's a script you can feed to `sh` either local or remotely
(i.e. `cat bootstrap | ssh -i secretkey root@yourcomputer sh -es`)

```
######################
# configuration

# location of encrypted volume:

DEVICE_SERIAL=OCZ-6X24O1T3V1DZJJ6S
START_512_SECTOR=46446454
END_512_SECTOR=117231368

# volume parameters:

SECTOR_SIZE=4096
PASSPHRASE=iaalAkLYTjDAI2zmnOGF6uVnyJRobtY7RJTyo5tDD91wAzxD
CIPHER=serpent-cbc-essiv:sha256
KEY_SIZE=256
VOLUME_NAME=data

######################
# calculate params

# get device file by serial#

name_serial=`lsblk -d -Ppno NAME,SERIAL | grep $DEVICE_SERIAL`
DEVICE=`echo $name_serial' ; echo $NAME' | sh -s`

# calculate --offset and --sizelimit for losetup
# (use bc because unlike sh, bc precision is not limited by CPU bit width)

ALIGNED_START=`echo "($START_512_SECTOR * 512 + $SECTOR_SIZE - 1) / $SECTOR_SIZE" | bc`
ALIGNED_END=`echo "$END_512_SECTOR * 512 / $SECTOR_SIZE" | bc`
PARTITION_OFFSET=`echo "$ALIGNED_START * $SECTOR_SIZE" | bc`
PARTITION_SIZE=`echo "($ALIGNED_END - $ALIGNED_START) * $SECTOR_SIZE" | bc`

######################
# check prerequisites

# device must exist

if [ ! -b "$DEVICE" ] ; then
    echo "Device $DEVICE_SERIAL does not exist"
    exit 1
fi

# essential directores must be overlapped by tmpfs

for dir in /tmp /var/log ; do
    if [ x`findmnt -no FSTYPE $dir` != xtmpfs ] ; then
        echo "Bad filesystem on $dir"
        exit 1
    fi
done

# no open files in temp directories

for dir in /tmp /var/tmp ; do
    lsof -t $dir || continue
    echo "$dir contains files opened by processes with those IDs"
    exit 1
done

#########################
# overlap /mnt directory

if [ x`findmnt -no FSTYPE /mnt` != xtmpfs ] ; then
    mount -t tmpfs -o size=64K tmpfs /mnt
fi

#########################
# mount encrypted volume

LOOP_DEVICE=`losetup --show -f $DEVICE --offset $PARTITION_OFFSET --sizelimit $PARTITION_SIZE --sector-size $SECTOR_SIZE`

# Echoing passphrase to cryptsetup looks least evil, this will only flash in the list of processes.
# If we used here-doc, it would be saved off somewhere.
# The best solution would be adding a pipe to the driver program
# so we could use a file descriptor to read passphrase from it.
# Related question: how pipe buffers are cleaned in the kernel if cleaned at all?
echo $PASSPHRASE | cryptsetup open $LOOP_DEVICE $VOLUME_NAME --type plain --cipher $CIPHER --key-size $KEY_SIZE --key-file -

if ! blkid /dev/mapper/$VOLUME_NAME >/dev/null ; then
    echo "/dev/mapper/$VOLUME_NAME is not formatted"
    exit 1
fi

mkdir -p /mnt/$VOLUME_NAME
mount /dev/mapper/$VOLUME_NAME /mnt/$VOLUME_NAME

#######################
# bootstrap the system

# stop containers

for dir in /var/lib/lxc/* ; do
    if [ -d $dir ] ; then
        container=`basename $dir`
        lxc-stop -n $container || true
    fi
done

# signal handlers to always start networking container after bootstrap

trap "lxc-start -n networking" EXIT
trap "trap - EXIT ; lxc-start -n networking" INT

# run bootstrap script

[ -x /mnt/$VOLUME_NAME/bootstrap-lxcex ] && /mnt/$VOLUME_NAME/bootstrap-lxcex $VOLUME_NAME
```

The script does the very minimum, delegating all the rest to `bootstrap-lxcex` located on the hidden volume.
Some aspects:
* Device is identified by serial number. Run `lsblk -d -pno NAME,SERIAL` to list them all.
* Serpent cipher can be faster than AES on retro hardware with no AES acceleration.
  On modern CPUs AES is preferred.
* /mnt is overlapped with tmpfs to avoid exposing the use of hidden volume
* The script stops if hidden volume is not formatted. So when you run it for the first time, you can proceed with formatting manually.

Remember, PASSPHRASE is sensitive data, you should keep this script encrypted with a strong algorithm,
in a place unreachable for criminals. This aspect of implementation is up to you.

Here's the next script, `bootstrap-lxcex`:
```
#!/bin/sh -e

VOLUME_NAME=$1

if [ -z "$VOLUME_NAME" ] ; then
    echo "Need volume name"
    exit 1
fi

# make a clean view of rootfs

rootfs_device=`findmnt -no SOURCE /`
if findmnt /mnt/root >/dev/null ; then
    echo "WARNING: /mnt/root already mounted"
else
    mkdir -p /mnt/root
    mount $rootfs_device /mnt/root
fi

# bind /var/lib/lxc to encrypted volume

if [ ! -d /mnt/${VOLUME_NAME}/var/lib/lxc ] ; then
    mkdir -p -m 751 /mnt/${VOLUME_NAME}/var/lib/lxc
fi
if findmnt /var/lib/lxc >/dev/null ; then
    echo "WARNING: /var/lib/lxc already mounted"
else
    mount --bind /mnt/${VOLUME_NAME}/var/lib/lxc /var/lib/lxc
fi

# add original containers

for dir in /mnt/root/var/lib/lxc/* ; do
    if [ -d $dir ] ; then
        container=`basename $dir`
        mkdir -p /var/lib/lxc/$container
        if findmnt /var/lib/lxc/$container ; then
            echo "WARNING: /var/lib/lxc/$container already mounted"
        else
            mount --bind /mnt/root/var/lib/lxc/$container /var/lib/lxc/$container
        fi
    fi
done

# /tmp can be relatively small to fit in RAM,
# but /var/tmp needs much more space so remount it

if [ x`findmnt -no FSTYPE /var/tmp` = xtmpfs ] ; then
    umount /var/tmp
fi
if ! findmnt -no SOURCE /var/tmp | grep /dev/mapper/${VOLUME_NAME} >/dev/null ; then
    if [ ! -d /mnt/${VOLUME_NAME}/var/tmp ] ; then
        mkdir -p -m 1777 /mnt/${VOLUME_NAME}/var/tmp
    fi
    mount --bind /mnt/${VOLUME_NAME}/var/tmp /var/tmp
fi

# overlap /root

if ! findmnt /root >/dev/null ; then
    if [ ! -d /mnt/${VOLUME_NAME}/root ] ; then
        cp -a /root /mnt/${VOLUME_NAME}/
    fi
    cwd=`pwd`
    cd /
    mount --bind /mnt/${VOLUME_NAME}/root /root
    cd $cwd
fi

# overlap files in /etc

if [ -d /mnt/${VOLUME_NAME}/etc ] ; then
    for entry in /mnt/${VOLUME_NAME}/etc/* ; do
        if [ -f $entry ] ; then
            dest=/etc/`basename $entry`
            if [ -e $dest ] ; then
                mount --bind $entry $dest
            else
                echo "WARNING: $dest does not exist, thus it cannot be overlapped with $entry"
            fi
        else
            echo "WARNING: skipping non-regular file $entry"
        fi
    done
fi

# start necessary containers: VPNs, Tor, etc.

# leave /mnt/root mounted for backup purposes -- XXX on shutdown unmount tmpfs fails because of this, need to fix

# finally, start your emergency kill switch
```

The script is self-explaining, you can add necessary functionality by your taste.

I strongly recommend to overlap /root directory because you'll definitely need absolutely different SSH keys
and you may want to keep your bash history, avoiding the risk of accidental exposure.

Also, you may want to overlap some files in /etc, but I strongly recommend not to do this. Personally, I overlap only /etc/hosts.

## Good luck

and don't flash in [crime reports](https://github.com/jlopp/physical-bitcoin-attacks).
