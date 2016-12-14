#!/bin/bash

#
# Wrapper around /bin/rm to prevent accidental 'rm -rf /'
#
rm (){
local rm=$(which rm)

case $1 in
  -rf)
    if [ / = "$2" ]; then
      echo "Back up buddy! WTH R U doing trying to remove me /??!"
    else
      echo "$rm \"$@\""
    fi
esac

}

#
# Clean up script
#
clean() {
        rm -rfv /usr/portage/distfiles/* /var/tmp/* /var/log/portage/*
        rm /tmp/*.torrent

        find /home/wumaster/irclogs -type f -iname '*ricer*' -exec shred -v -u -z '{}' \;

        for i in /home/wumaster/.bash_history /root/.bash_history; do
                shred -v -u -z $i
        done
}

#
#  IPTABLES function to ban a given ip address
#
ban-ip() {
  iptables -A INPUT -s $1 -j DROP
}

#
# Search for files of a given size
#
e-find() {
          find / -regex '^/\(dev\|sys\|lost\+found\|mnt\|proc\)' -prune -o -type f -size +"${1}"M -printf "%-12s%p\n"
}

#
# Creates a snapshot of a given ZoL pool
#
zfs-snapshot() {
        if [ $# -lt 1 ]; then
                echo "You need a pool to snapshot!"
        else
                zfs snapshot -r "$1"@lappy-$(date +%Y%m%d)
        fi
}

#
# My personal password generator script
#
e-ranpasswd() {
        local length="$1" excludes="$2"
        local x=$(($length+10))
        local y=$(($x-10))

        head -c $length /dev/random | uuencode -m - | sed -n 2p | tr '[=$excludes]' ' ' | head -c $y
        echo -e "\nYour generated password phrase is above."
}

#
# Extract those movies you rented from blockbuster
#
e-unrar() {
        for file in [Cc][Dd][1-20]; do
                cd "$file"

                find -type f -name '*.part0*1.rar' -exec unrar x {} \;
                grep -E '*.r+' *.sfv | cut -d' ' -f1 | xargs rm

                cd $OLDPWD
        done
}

#
# Generate an ssl certificate signing request
#
e-openssl() {
        openssl genrsa -des3 -out "$1".key "$2"
        openssl req -new -key "$1".key -out "$1".csr

        echo "Backing up the private key"
        cp "$1".key "$1".key.bck

        openssl rsa -in "$1".key.bck -out "$1".key
        openssl x509 -req -days 365 -in "$1".csr -signkey "$1".key -out "$1".crt

        echo "All done!"
}

#
# Just various ways to create computer noise
#
e-noise() {
        case $1 in
                --wn)
                        echo "The White Noise"
                        play -c2 -n synth whitenoise band -n 100 24 band -n 300 100 gain +20
                        ;;
                --gcc)
                        echo "The Gcc Noise"
                        echo "main(i){for(i=0;;i++)putchar(((i*(i>>17|i>>9)&46&i>>3))^(i&i>>10|i>>100));}" | gcc -x c - && ./a.out | aplay
                        ;;
                --tcpdump)
                        echo "tcpdump Noise"
                        tcpdump -i eth0 -n -l -w - | aplay -c 2
                        ;;
                *)
                        echo "You need one of --wn,--gcc or --tcpdump"
        esac
}

#
# Prints out all the sector size information for all /dev/sd* devices
#
e-chksectorcount() {
  local -a drives=(/dev/sd*)

  # Iterate through array to remove partitions i.e /dev/sda1 and so on
  ((n_elements=${#drives[@]}, max_index=n_elements - 1))

  for ((i = 0; i <= max_index; i++)); do
    if [[ $(echo ${drives[i]} | grep -v '[0-9]') ]]; then
      smartctl -a ${drives[i]} | grep -E 'Sector Size(s?)'|sed "s:^:${drives[i]} :"
    else
      unset 'drives[i]'
      continue
    fi
  done
}

#
# Sprunge script to upload files or pipe output
#
sprunge() {
        if [ $# -eq 0 ] || { [ $# -eq 1 ] && [ x- = "x$1" ]; }; then
                curl -F 'sprunge=<-' http://sprunge.us
        else
                local f
                for f; do
                        [ -f "$f" ] || continue
                        echo "Paste of: $f"
                        curl -F 'sprunge=<-' http://sprunge.us < "$f"
                done
        fi
}

#
# Extracts the contents of a compressed initrd image into a tmp directory
#
e-extract_cpio() {
        mkdir /tmp/cpio
        cd /tmp/cpio

        cat "$1" | unxz -d | cpio -idm --quiet -H newc
}

#
# Prints gcc suggested flags for use with compiling
#
e-gcc-check-cflags() {
        case ${1} in
                --verbose|-v)
                        echo 'int main(){return 0;}' > test.c && gcc -v -Q -march=native -O2 test.c -o test && rm test.c test
                        ;;
                *)
                        gcc -O2 -march=native -Q --help=target
        esac
}

e-drush() {
  local dbin=$(which drush)

  if ! hash drush; then
    echo "Drush command not available, exiting"
    exit 1
  fi

  case $1 in
    fwd-staging)
      ${dbin} -y rsync -acv --delete-before --progress @dev:htdocs/ @staging:htdocs
      ${dbin} -y sql-sync @dev @staging --no-cache
    ;;
    forward|fwd)
      ${dbin} -y rsync -acv --delete-before --progress @dev:htdocs/ @prod:htdocs
      ${dbin} -y sql-sync @dev @prod --no-cache
    ;;
    rev-staging)
      ${dbin} -y rsync -acv --delete-before --progress @staging:htdocs/ @dev:htdocs
      ${dbin} -y sql-sync @staging @dev --no-cache
    ;;
    reverse|rev)
      ${dbin} -y rsync -acv --delete-before --progress @prod:htdocs/ @dev:htdocs
      ${dbin} -y sql-sync @prod @dev --no-cache
      ;;
    *) ${dbin} "${@}"
      ;;
  esac
}

#
# Find the ATA ID of all sd block devices
#
e-ata() {
        for device in /sys/block/sd*; do
                local name=$(basename ${device})

                host=$(readlink $device | egrep -o "host[0-9]+")
                target=$(readlink $device | egrep -o "target[0-9:]*")

                x=$(echo $target | egrep -o "[0-9]:[0-9]$" | sed 's/://')
                y=$(</sys/class/scsi_host/$host/unique_id)

                echo "$name -> ata${y}.$x"
        done
}

#
# Mounts a qemu virtual drive image
#
e-qemu-mount() {
        case $1 in
                mount)
                        if [ "$#" -lt 1 ]; then
                                echo "usage: e-qemu-mount mount /image.img"
                                exit 0
                        fi

                        if ! [[ $(lsmod | grep nbd) ]]; then
                                modprobe nbd max_part=63
                                if [ -r "$2" ]; then
                                        qemu-nbd -c /dev/nbd0 $2
                                        mount /dev/nbd0p1 /mnt/qemu-img
                                else
                                        echo "$2 not readable"
                                        modprobe -r nbd
                                        exit 1
                                fi
                        fi
                        ;;
                umount)
                        if [[ $(mount|grep "/mnt/qemu-img") ]]; then
                                umount /mnt/qemu-img
                                killall qemu-nbd
                                modprobe -r nbd
                        else
                                echo "Nothing to umount!"
                        fi
                        ;;
                *) echo "Try parameters mount or umount"
        esac
}

#
# Stops LAMP related daemons
#
e-lamp() {
        case $1 in
                start|-s)
			if [ $2 = "systemd" ]; then
				for daemon in mysqld.service nginx.service php-fpm@5.6.service; do
					systemctl start "$daemon"
				done
                        else
				for daemon in memcached mysql php-fpm; do
                                	rc-service "$daemon" start
                        	done
			fi
                        ;;
                stop|-h)
			if [ $2 = "systemd" ]; then
				for daemon in mysqld.service nginx.service php-fpm@5.6.service; do
					systemctl stop "$daemon"
				done
			else
			        for daemon in memcached mysql php-fpm nginx; do
                        	        rc-service "$daemon" stop
                        	done
			fi
			;;
                *) echo "Failed!! try lamp {start,stop} punk"
        esac
}

#youtube() {
#  mplayer -fs $(youtube-dl -g "$1")
#}

#
# Gentoo Linux emerge wrapper to help with toolchain rebuilding
# by allowing emerging of @system and or @world toolchain packages
# from being added to the list
#
emerge() {

local emerge=$(which emerge)

case $1 in
        -ew)
                $emerge $(emerge -ep --columns @world| awk '{print$4}' | \
grep -e '[a-z]*-[a-z]*/[a-z]' | uniq | egrep -v "(glibc|portage|binutils|gcc|linux(26)?\-headers)") --keep-going -1
                ;;
        -es)
                $emerge $(emerge -ep --columns @system| awk '{print$4}' | \
grep -e '[a-z]*-[a-z]*/[a-z]' | uniq | egrep -v "(glibc|portage|binutils|gcc|linux(26)?\-headers)") --keep-going -1
                ;;
        sync|--sync)
                echo "Running emerge --sync"
                $emerge --sync
                ;;
        -s) shift
                echo "No eix search is faster"
                eix "$@"
                ;;
        digest|manifest)
                a=$(find . -maxdepth 2 -type f -name '*.ebuild' | sort | head -n1)
                ebuild "$a" manifest
                ;;
        compile)
                a=$(find . -maxdepth 1 -type f -name '*.ebuild' | sort | head -n1)
                ebuild "$a" compile
                ;;
        install)
                a=$(find . -maxdepth 1 -type f -name '*.ebuild')
                ebuild "$a" clean install
                ;;
        unmask)
                if [ "$#" -lt 2 ]; then
                        echo "Not enough parameters. try.."
                        echo "emerge unmask <category> <keyword>. i.e emerge unmask games-puzzle ~x86"
                        exit 1
                fi

                ls -I metadata.xml --color=no /usr/portage/$1 | sed 's@^@\'$1'/@' | \
while read line;do
        echo "$line $3" >>/etc/portage/package.keywords
done
                ;;
        ricer|breakme|0mg|breakage|letitburn)
                find /usr/portage/ -maxdepth 2 -mindepth 2 -type d -wholename '*-*' | \
egrep -v 'packages/|distfiles/|eclass/|licenses/|metadata/|profiles/|\
virtual/' | cut -d/ -f 4-5 | \
while read line; do
        echo "$line -*" >>/etc/portage/package.keywords
done

                ;;
        *) $emerge "$@"
esac

}

#
# Prints a list of packages located in @world or @system sets
# or print local and global settings i.e DISTDIR or CFLAGS
#
e-show() {

case $1 in
        world|-w)
                eix --world --only-names | less
        ;;
        system|-s)
                eix --system --only-names | less
        ;;
        *)
                a=$(echo $1|tr [:lower:] [:upper:])
                echo "Local System Settings"; sed -n 's:^'${a}'=::p' /etc/portage/make.conf
                echo "Global System Settings"; sed -n 's:^'${a}'=::p' /usr/share/portage/config/make.globals
esac
}

#
# Print id3 tag information for mp3s.
#
e-id3info() {
case $1 in
        rmp3s)
                for mp3 in *.mp3; do
                        title=$(id3info "$mp3" | awk '/TIT2/' | cut -d: -f2 | sed "s:['.]::" | xargs echo | tr ' ' '_')
                        artist=$(id3info "$mp3" | awk '/TPE1/' | cut -d: -f2 | sed "s:['.]::" | xargs echo | tr ' ' '_')

                        val_artist=$(id3info "$mp3" | sed -n 2p | grep Artist)
                        val_title=$(id3info "$mp3" | sed -n 2p | grep Title)

                if [ ! -z "$val_artist" ] && [ ! -z "$val_title" ]; then
                        echo "${title}-${artist}.mp3"
                fi
                done
        ;;
esac
}

e-sysctl() {
        case $1 in
                --lock)
                        sed -i 's/new_usb = 0/new_usb = 1/' /etc/sysctl.d/local.conf
                        sysctl --system
                        ;;
                --unlock)
                        sed -i 's/new_usb = 1/new_usb = 0/' /etc/sysctl.d/local.conf
                        sysctl --system
                        ;;
                *)
                        echo "Invalid option"
                        exit
        esac
}

alias e-logind-check='loginctl show-session $XDG_SESSION_ID'

