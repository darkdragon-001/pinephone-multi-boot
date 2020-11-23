#!/bin/sh

if [ "$(whoami)" != "root" ] ; then
	exec sudo sh "$0" "$@"
fi

source ./config

umount m
losetup -d $(losetup -l | grep $IMG | cut -d ' ' -f 1)
