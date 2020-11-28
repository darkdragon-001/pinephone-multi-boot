#!/bin/bash

if [ "$(whoami)" != "root" ] ; then
	exec sudo sh "$0" "$@"
fi

source ./config

L=`losetup -P --show -f $IMG`
mkdir -p m
mount -o compress-force=zstd ${L}p2 m
