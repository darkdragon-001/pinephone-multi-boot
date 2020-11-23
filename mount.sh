#!/bin/sh

if [ "$(whoami)" != "root" ] ; then
	exec sudo sh "$0" "$@"
fi

source ./config

L=`losetup -P --show -f $IMG`
mount -o compress-force=zstd ${L}p2 m
