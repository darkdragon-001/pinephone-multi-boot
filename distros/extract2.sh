#!/bin/sh

L=`losetup -P --show -f "$1"`

mkdir -p m
mount ${L}p2 m
mount ${L}p1 m/boot
bsdtar -cvf - -C m --numeric-owner . | zstd -z -T0 -19 - > rootfs.tar.zst
umount m/boot
umount m
rmdir m

losetup -d $L
