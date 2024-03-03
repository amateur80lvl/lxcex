# Chapter 8.
# Sharing files

The simplest way to share files across containers is a folder on the host system, e.g.
```
mkdir /var/share
chmod 777 /var/share
```

mounted to containers with the following option:

```
lxc.mount.entry = /var/share var/share none bind,create=dir 0 0
```

However, such an approach is not the best one because the owner will be set `nobody:nogroup`
but file permissions remain original and you may fail to read files with zero bits for `others`.

Ideally, each user in any container should see shared directory as if it was their own
and I found it's possible to implement this with idmapped mounts.

Although idmapped mount was implemented yet in some 5.x kernel, the mount utility
supports it only since `util-linux` version 2.39, which, for Devuan, means it's
supported only in Excalibur and above.
Actually, things are worse.
I gave both Excalibur and Ceres a try and failed to specify custom mappings:
```
mount --bind -o X-mount.idmap=b:100000:0:65536 /mnt/src /mnt/test
mount: /mnt/test: failed to parse mount options 'rw,bind,X-mount.idmap=b:100000:0:65536': No such file or directory.
```
It looks like supporting only user namespace file for `X-mount.idmap`.

Luckily, this utility https://github.com/brauner/mount-idmapped works like a charm:
```
mount-idmapped --map-mount b:100000:0:65536 /mnt/src /mnt/test
```

In case you're don't know how to compile it, download the source and run:
```
gcc -o /usr/local/bin/mount-idmapped mount-idmapped.c
```

There's one point for LXC containers, however: if `mount-idmapped` is called
from `mount` hook, it hangs indefinetely.
This can be worked around by mounting idmapped points to intermediate
locations in `pre-start` hook and then `rbind` them to final destinations
in `mount` hook.

## Idmapped fanout mounts

I call the basic idea as _idmapped fanout mounts_.
Suppose you have a directory on the host you want to share: `/var/share`.
To share it with users in containers you mount it to each user as:
```
dest_dir=/var/lib/lxc/container/rootfs/home/user

from_uid=`stat -c %u /var/share`
from_gid=`stat -c %g /var/share`

to_uid=`stat -c %u $dest_dir`
to_gid=`stat -c %g $dest_dir`

mount-idmapped \
    --map-mount u:$from_uid:$to_uid:1 \
    --map-mount g:$from_gid:$to_gid:1 \
    /var/share $dest_dir
```
Actually, the above code won't work, it just illustrates the idea.
You'll need an idmapped mount for each user participating in file sharing.
They say the number of idmaps is limited by 340, and I suppose
there's a fixed-size array somewhere in kernel.
Nevertheless, I think it's more than enough for a desktop system.

Note that shared directory must have non-root owner.
I don't know why, but idmapped mount scheme does not work
for root-owned directories. Basically, this is good, but I have no
time to investigate and am still curious why.

## Use case 1: shared directories

This is a simple sharing scheme your mind was seeded with from the beginning of this chapter.

LXC configuration:
```
lxc.hook.pre-start = /usr/local/share/lxcex/hooks/share.pre-start /var/shared-dir-name
lxc.hook.mount     = /usr/local/share/lxcex/hooks/share.mount     /var/shared-dir-name
lxc.hook.post-stop = /usr/local/share/lxcex/hooks/share.post-stop /var/shared-dir-name
```

The directory is not necessary to be located in `/var`.
It is shared with all users that have `shared-dir-name` subdirectory in their home directories.
There can be multiple shared directories, they can be shared across groups of containers.
All you need is to create a directory for sharing, create mount points in user's home directories,
and add triplet of hooks to container configuration files.

Hooks:
* [share.pre-start](https://github.com/amateur80lvl/lxcex/tree/main/base-system/usr/local/share/lxcex/hooks/share.pre-start):
  create intermediate idmapped mounts in `/mnt/thunks/share`
* [share.mount](https://github.com/amateur80lvl/lxcex/tree/main/base-system/usr/local/share/lxcex/hooks/share.mount):
  bind mounts from `/mnt/thunks/share` to container's rootfs.
* [share.post-stop](https://github.com/amateur80lvl/lxcex/tree/main/base-system/usr/local/share/lxcex/hooks/share.post-stop):
  drop intermediate idmapped mounts from `/mnt/thunks/share`

## Use case 2: shared projects

Suppose you're working on private projects and have a container with editing software.
You disabled networking for that container because editors can be dangerous nowadays.
For example, text editors may try to "improve your writing" by sending your data
to a third party and you can easily overlook this feature is magically turned on after
software upgrade.
Another example is LibreOffice that needs unrestricted `/proc` and who knows what for.
I bet it sends everything it knows somewhere, especially when crashed and I'm not sure
I'm able to disable this without auditing its settings at least, not mentioning the codebase.

But you still need networking for sharing your work with colleagues.
Or, you may have multiple identities, say, on github:
one is fully anonymous, accessed via Tor, and for another clearnet is okay.

So you put all your data to multiple containers, presumably with different networking schemes,
but you want to edit your data from a single container.

Here's the recipe:
```
lxc.hook.pre-start = /usr/local/share/lxcex/hooks/share-projects.pre-start username container1 container2 ...
lxc.hook.mount     = /usr/local/share/lxcex/hooks/share-projects.mount
lxc.hook.post-stop = /usr/local/share/lxcex/hooks/share-projects.post-stop
```

`username` is the name of user within container. Its home directory must have `projects` subdirectory.
Other arguments are _foreign_ containers. They are searched for home directories containing
`projects` subdirectory and if it is present, it is mounted to `username`'s home this way:
```
container1_rootfs/home/foreign_user1/projects -> /home/username/projects/foreign_user1
container1_rootfs/home/foreign_user2/projects -> /home/username/projects/foreign_user2
container2_rootfs/home/foreign_user3/projects -> /home/username/projects/foreign_user3
```

Hooks:
* [share-projects.pre-start](https://github.com/amateur80lvl/lxcex/tree/main/base-system/usr/local/share/lxcex/hooks/share-projects.pre-start):
  create intermediate idmapped mounts in `/mnt/thunks/share-projects`
* [share-projects.mount](https://github.com/amateur80lvl/lxcex/tree/main/base-system/usr/local/share/lxcex/hooks/share-projects.mount):
  bind mounts from `/mnt/thunks/share-projects` to container's rootfs.
* [share-projects.post-stop](https://github.com/amateur80lvl/lxcex/tree/main/base-system/usr/local/share/lxcex/hooks/share-projects.post-stop):
  drop intermediate idmapped mounts from `/mnt/thunks/share-projects`
