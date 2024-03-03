# Chapter 7.
# Storage optimization

While `composefs` is on the way, let's give `btrfs` a try.
Never used it before, brcause from various readings I conclude it's a woe.

But for system volume which contain system software only it could be a win because of deduplication.

Let's bear in mind the following:
https://archive.kernel.org/oldwiki/btrfs.wiki.kernel.org/index.php/FAQ.html#if_your_device_is_small

In the base system let's
```bash
apt-install btrfs-progs
```

Use a separate volume for:
/home
/tmp (if not tmpfs)
/var
including containers -- add appropriate lxc.mount to configs.

mount -t btrfs --mixed --nodiscard /dev/sda1

rsync -rltvWpogH --devices --specials --exclude /home --exclude /var --exclude /lost+found --exclude /tmp /mnt/root/ /mnt/ssd/
mkdir /mnt/ssd/home
mkdir /mnt/ssd/var
mkdir /mnt/ssd/tmp
chmod ugo+rwxt /mnt/ssd/tmp
mkdir /mnt/data/var
mkdir /mnt/data/home


cp -a /home/user /mnt/data/home/

rm /var/backups/*
cp -a /var/{spool,opt,mail,local,cache,backups} /mnt/data/var/
rsync -rltvWpogH --specials --devices --exclude lxc /mnt/root/var/lib /mnt/data/var/
ln -s /run /mnt/data/var/
ln -s /run/lock /mnt/data/var/
mkdir /mnt/data/var/tmp
chmod ugo+rwxt /mnt/data/var/tmp
mkdir /mnt/data/var/log
mkdir /mnt/data/var/log/apt
mkdir /mnt/data/var/log/fsck
mkdir /mnt/data/var/log/runit

rm /home/user/.bash_history 
rm -rf /home/user/.cache
rm /home/user/.lesshst 
rm /var/lib/lxc/gui-base/rootfs/root/.bash_history 
rm -rf /var/lib/lxc/gui-base/rootfs/root/.local
rm -rf /var/lib/lxc/gui-base/rootfs/home/user/.cache/


Change lxc location: create /etc/lxc/lxc.conf:
lxc.lxcpath = /lxc


mkdir /mnt/ssd/lxc

LXC config:

# /var
lxc.mount.entry = /mnt/data/lxc/var var none bind 0 0
