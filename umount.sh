#!/bin/bash

if [ "$(whoami)" != "root" ] ; then
	exec sudo sh "$0" "$@"
fi

source ./config

umount m
rmdir m
losetup -d $(losetup -l | grep $IMG | cut -d ' ' -f 1)
