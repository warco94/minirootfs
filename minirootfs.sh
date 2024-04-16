#!/bin/bash

set -e

cd "$(dirname "${0}")"

if [ $# -ne 1 ]; then
	echo "error: usage: ${0} <toolchain_prefix>"
	exit 1
fi

if [ "$(id -u)" != "0" ]; then
	echo error: must be root, use fakeroot command
	exit 1
fi

toolchain=${1}
cc=${toolchain}gcc

if [ -z "$(which $cc)" ]; then
	echo error: toolchain not found: $cc
	exit 1
fi

stage_dir=/tmp/rootfs-$$
cwd_dir=$(pwd)
sysroot_dir=$($cc --print-sysroot)
ncore=$(nproc)

if [ ! -d "$sysroot_dir" ]; then
	echo error: sysroot folder not found: $sysroot_dir
	exit 1
fi

cleanup() {
	[ ! -d "$stage_dir" ] || rm -rf "$stage_dir" >/dev/null 2>&1
}

trap cleanup INT ERR TERM EXIT

echo -e "\nBuild rootfs structure\n"
mkdir "$stage_dir"

mkdev() {
	if [ $# -ne 5 ]; then
		return 1
	fi
	mknod $1 $2 $3 $4 || return 1
	chmod $5 $1 || return 1
	return 0
}

# basic directories
cd "$stage_dir"
mkdir proc
mkdir sys
mkdir dev
mkdir lib
mkdir usr
mkdir usr/sbin
mkdir var
mkdir var/run
mkdir var/log
mkdir var/lock
mkdir etc
mkdir sbin
mkdir bin
mkdir tmp
mkdir mnt
mkdir mnt/floppy
mkdir mnt/rwfs
mkdir root
mkdir home

# create devices
mkdir dev/pts
mkdir dev/net
mkdir dev/shm
mkdir dev/input
mkdir dev/misc

mkdev dev/tty			c		5		0		666
mkdev dev/tty1	 		c		4		1		666
mkdev dev/tty2	 		c		4		2		666
mkdev dev/tty3			c		4		3		666
mkdev dev/tty4			c		4		4		666
mkdev dev/ttyS0			c		4		64		666
mkdev dev/console		c		5		1		666
mkdev dev/null			c		1		3		666
mkdev dev/zero			c		1		5		666
mkdev dev/random		c		1		8		666
mkdev dev/urandom		c		1		9		666
mkdev dev/mem			c		1		1		640
mkdev dev/kmem			c		1		2		640
mkdev dev/kmsg			c 		1		11		640
mkdev dev/ram			b		1		1		640
mkdev dev/ram0			b		1		0		640
mkdev dev/ram1			b		1		1		640
mkdev dev/ram2			b		1		2		640
mkdev dev/ram3			b		1		3		640
mkdev dev/loop			b		7		0		640
mkdev dev/ptmx			c		5		2		666

mkdev dev/fb0			c		29		0		640
mkdev dev/watchdog		c		10		130		666
mkdev dev/rtc			c		254		0		666

mkdev dev/mtd0			c		90		0		640
mkdev dev/mtd1			c		90		2		640
mkdev dev/mtd2			c		90		4		640
mkdev dev/mtd3			c		90		6		640
mkdev dev/mtd4			c		90		8		640
mkdev dev/mtd5			c		90		10		640
mkdev dev/mtd6			c		90		12		640
mkdev dev/mtdblock0		b		31		0		640
mkdev dev/mtdblock1		b		31		1		640
mkdev dev/mtdblock2		b		31		2		640
mkdev dev/mtdblock3		b		31		3		640
mkdev dev/mtdblock4		b		31		4		640
mkdev dev/mtdblock5		b		31		5		640
mkdev dev/mtdblock6		b		31		6		640

mkdev dev/mmcblk0		c		179		0		640
mkdev dev/mmcblk0p1		c		179		1		640
mkdev dev/net/tun		c		10		200		660

mkdev dev/i2c-0			c		89		0		660
mkdev dev/i2c-1			c		89		1		660

# setup /proc
ln -s /proc/self/fd/0 stdin
ln -s /proc/self/fd/1 stdout
ln -s /proc/self/fd/2 stderr
ln -s /proc/mounts etc/mtab

# copy libc dynamic libraries
echo -e "\nCopy dynamic libraries\n"
for d in etc bin sbin lib usr/bin usr/sbin usr/lib; do
	if [ -d "$sysroot_dir/$d" ]; then
		mkdir -p "$stage_dir/$d"
		rsync -rlpDS "$sysroot_dir/$d"/ "$stage_dir/$d"/
	fi
done

# build busybox
echo -e "\nBuild busybox\n"
busybox_ver=1.36.1
cd "$cwd_dir"/busybox-${busybox_ver}
rsync -a "$cwd_dir"/busybox-${busybox_ver}.config .config
make ARCH=arm CROSS_COMPILE=$toolchain -j$ncore
make ARCH=arm CROSS_COMPILE=$toolchain CONFIG_PREFIX="$stage_dir" install
cd -

# copy skeleton files
echo -e "\nCopy skeleton files\n"
rsync -a "$cwd_dir"/skel/ "$stage_dir"

# clean rootfs
echo -e "\nStrip rootfs\n"
for d in locale gconv; do
	find "$stage_dir" -type d -name "$d" | xargs rm -rf
done
find "$stage_dir" -type f \( -name "*.o" -o -name "*.a" \) | xargs rm -rf
find "$stage_dir" -type f -executable |\
	xargs -I{} file --separator " " "{}" | grep ARM | awk '{print $1}' |\
	xargs -I{} ${toolchain}strip -s "{}"

# create initramfs
echo -e "\nCreate initramfs\n"
find . | cpio --quiet -H newc -o | gzip -9 -n > "$cwd_dir"/initramfs.cpio.gz

echo -e "\nDone\n"
