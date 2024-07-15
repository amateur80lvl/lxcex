# LXCex Packages Directory

* `ppa`: packages repository for apt, see `common-files/etc/apt/sources.list.d/lxcex.sources`
* `patches`: patches for existing packages to recompile
  * `lxcfs.patch`: backported this patch https://github.com/lxc/lxcfs/pull/626
  * `pulseaudio.patch`: fix socket directory permission to make it group-traversable
* `prepare`: this script installs all necessary dependencies and configures the system. Must be run as root!!!
* `build`: this script builds packages and adds them to the PPA

Other directories are packages maintained by LXCex.
