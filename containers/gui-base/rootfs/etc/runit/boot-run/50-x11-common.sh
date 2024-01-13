# based on /etc/init.d/x11-common

X11_SOCKET_DIR=.X11-unix
X11_ICE_DIR=.ICE-unix


x11_restorecon () {
  # Restore file security context (SELinux).
  if command -v restorecon >/dev/null 2>&1; then
    restorecon "$1"
  fi
}

# create a directory in /tmp.
# assumes /tmp has a sticky bit set (or is only writeable by root)
x11_set_up_dir () {
  DIR="/tmp/$1"

  # if $DIR exists and isn't a directory, move it aside
  if [ -e $DIR ] && ! [ -d $DIR ] || [ -h $DIR ]; then
    mv "$DIR" "$(mktemp -d $DIR.XXXXXX)"
  fi

  error=0
  while :; do
    if [ $error -ne 0 ] ; then
      # an error means the file-system is readonly or an attacker
      # is doing evil things, distinguish by creating a temporary file,
      # but give up after a while.
      if [ $error -gt 5 ]; then
        echo "failed to set up $DIR"
        return 1
      fi
      fn="$(mktemp /tmp/testwriteable.XXXXXXXXXX)" || return 1
      rm "$fn"
    fi
    mkdir -p -m 01777 "$DIR" || { rm "$DIR" || error=$((error + 1)) ; continue ; }
    case "$(LC_ALL=C stat -c '%u %g %a %F' "$DIR")" in
      "0 0 1777 directory")
        # everything as it is supposed to be
        break
        ;;
      "0 0 "*" directory")
        # as it is owned by root, cannot be replaced with a symlink:
        chmod 01777 "$DIR"
        break
        ;;
      *" directory")
        # if the chown succeeds, the next step can change it savely
        chown -h root:root "$DIR" || error=$((error + 1))
        continue
        ;;
      *)
        echo "failed to set up $DIR"
        return 1
        ;;
    esac
  done
  x11_restorecon "$DIR"

  return 0
}


setup_x11_common()
{
    x11_set_up_dir "$X11_SOCKET_DIR"
    x11_set_up_dir "$X11_ICE_DIR"
}

setup_x11_common
