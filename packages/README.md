# LXCex Packages Directory

* `devuan`: packages repository for apt, see `common-files/etc/apt/sources.list.d/lxcex.sources`
* `patches`: patches for existing packages to recompile
  * `lxcfs.patch`: backported this patch https://github.com/lxc/lxcfs/pull/626
  * `pulseaudio.patch`: fix socket directory permission to make it group-traversable
* `src`: sources for new packages
* `upstream`: upstream software sources
* `signing-key.gpg`: public key
