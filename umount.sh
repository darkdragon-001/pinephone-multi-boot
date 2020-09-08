#!/bin/sh

if [ "$(whoami)" != "root" ] ; then
	exec sudo sh "$0" "$@"
fi

umount m
losetup -d $(losetup -l | grep multi.img | cut -d ' ' -f 1)
