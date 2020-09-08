#!/bin/sh

if [ "$(whoami)" != "root" ] ; then
	exec sudo sh "$0" "$@"
fi

L=`losetup -P --show -f multi.img`
mount -o compress-force=zstd ${L}p2 m
