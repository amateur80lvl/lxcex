# Chapter 2.
# The basic networking

As you could see from previous chapter, no network configuration packages
were installed in our base system.
Basically, they are unnecessary because LXC does everything for you.
However you'll need to install more packages in the next chapter so you'll need to configure
your interfaces somehow.

You have a few options:
* install and configure ifupdown and skip to the next chapter;
* configure network interfaces with ip command and set default route manually;
* use an init script if you get tired to type ip address add after each reboot.

Here is that script:
[/etc/init.d/basic-networking](https://github.com/amateur80lvl/lxcex/tree/main/base-system/etc/init.d/basic-networking)

And here is a sample configuration file for it:

[/etc/default/basic-networking](https://github.com/amateur80lvl/lxcex/tree/main/base-system/etc/default/basic-networking)

How to install and run:
```bash
chmod +x  /etc/init.d/basic-networking
update-rc.d basic-networking defaults
invoke-rc.d basic-networking start
```

You may need to add an entry to your `/etc/resolv.conf`:
```
nameserver 1.1.1.1
```

Now, if `ping 1.1.1.1` works, you're ready to proceed to the next chapter.
