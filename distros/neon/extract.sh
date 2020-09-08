#!/bin/sh

L=`losetup -P --show -f "$1"`

mkdir -p m
mount ${L}p1 m
bsdtar -cvf - -C m --numeric-owner . | zstd -z -4 - > rootfs.tar.zst
umount m

losetup -d $L