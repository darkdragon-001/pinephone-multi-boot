#!/bin/sh

if [ "$(whoami)" != "root" ] ; then
	exec sudo sh "$0" "$@"
fi

L=`losetup -P --show -f "jumpdrive.img"`

mkdir -p m
mount ${L}p1 m
gzip -d -c m/initramfs.gz > initramfs
umount m
rmdir m

losetup -d $L

