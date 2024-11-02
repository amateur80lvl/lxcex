# Chapter 8.
# Sharing files

Sharing files and directories across containers is a complicated thing.
I tried a few setups and the most convenient for everyday use
was quite complicated "Idmapped fanout mounts" approach.
You can find it in
[this revision](https://github.com/amateur80lvl/lxcex/tree/e95f70ce48f20068d301cf186217e0b9d8e5bf08).

Nevertheless, it has fatal flaw: you can't add a share to a running container.
Not a big dead because adding containers and users is not an everyday task,
but it's really annoying to restart cozy environment.

I tried to revise sharing a few times but all attempts were unsuccessfull.
I stumbled across this blog post
https://brauner.io/2023/02/28/mounting-into-mount-namespaces.html
but it did not help.
And ony when I managed to get autofs mounts more or less usable,
it became clear how to improve previous approach.

## Private shares

Such kind of shares are used to grant permissions on someone's directory
to the only alien user.

First of all, let's make-rshared some mount point for sharing purposes on the host system:
```
mkdir /mnt/share-thunks
mount -t tmpfs -o size=1M --make-rshared tmpfs /mnt/share-thunks
```

Next, create a separate subdirectory for each container in it:
```
mkdir /mnt/share-thunks/alice-container
mkdir /mnt/share-thunks/bob-container
```

Add the following line to the container's configuration:
```
lxc.mount.entry = /mnt/share-thunks/<container-name> mnt/share-thunks none create=dir,rbind 0 0
```
Note: this is not necessary if helper hooks are used, see below.

Now, suppose we want to share `/home/alice/share` in container `foo`
to `/home/bob/share` in container `bar`.
Let's create an idmapped thunk:
```
mkdir /mnt/share-thunks/bob-container/alice-to-bob
mount-idmapped --map-mount u:1000:401000:1 --map-mount g:100:400100 \
    /var/lib/lxc/alice-container/rootfs/home/alice/share \
    /mnt/share-thunks/bob-container/alice-to-bob
```
where 400000 is subuid/subgid of Bob's container and
`--map-mount` assumes rootfs of Alice's container is idmapped.
If not,
```
mount-idmapped --map-mount u:301000:401000:1 --map-mount g:300100:400100
```
where 300000 is subuid/subgid of Alice's container.

Then, in the Bob's container we bind `/mnt/share-thunks/alice-to-bob` to its final destination:
```
mount --bind /mnt/share-thunks/alice-to-bob /home/bob/share
```

Of course, using broader idmap we could grant access to many users from other container,
but such approach usually leads to problems with file permissions.

## Common shares

This scheme provides access to a directory on the host system for many users
from different containers, as if it was their own directory with their own file permissions.

The approach is similar to private shares, the only difference is that idmapped thunks
are created for each container.

When using idmapped rootfs for containers, it does not matter where shared directory is located.
It could be someone's private directory, but it's better to reserve a space on the host system.

## lxcex-share

If invoked manually from command line, this script expects the following parameters:

```
lxcex-share <host-directory> <container-name> <user-name> <dest-directory>
```
where
* `host-directory`: path to directory to share on the host system
* `container-name`, `user-name`: container and user to share with
* `dest-directory`: path to the destination directory inside container

Examples:

1. Private share:
   ```
   lxcex-share /var/lib/lxc/alice-container/rootfs/home/alice/share bob-container bob /home/bob/share
   ```

2. Common share:
   ```
   lxcex-share /var/share/secrets alice-container alice /home/alice/secrets
   lxcex-share /var/share/secrets bob-container bob /home/bob/secrets
   lxcex-share /var/share/secrets malory-container malory /home/malory/secrets
   ```

### LXC hooks

The script can be used for the following LXC hook to automate sharing:
```
lxc.hook.pre-start = /usr/local/bin/lxcex-share
lxc.hook.mount     = /usr/local/bin/lxcex-share
lxc.hook.start     = /usr/local/bin/lxcex-share
lxc.hook.post-stop = /usr/local/bin/lxcex-share
```
Note that this script must exist in the container as well for the start hook.

If invoked as pre-start/post-stop hook, the script uses `sharetab` configuration file located in container's directory:
```
# host-directory  user-name  dest-directory

# private share
/var/lib/lxc/bob-container/rootfs/home/bob/share alice /home/alice/share

# shared directories
/var/share/secrets alice /home/alice/secrets
/var/share/public  alice /home/alice/public
```

## Notes on idmapped mount

Still relevant.

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

`mount-idmapped` does not work in unprivileged containers.

If `mount-idmapped` is called from `mount` hook, it hangs indefinitely.

## Shit I stepped in

https://discuss.linuxcontainers.org/t/container-hangs-on-startup-when-lxc-hook-start-host-script-is-calling-lxc-info/18621
