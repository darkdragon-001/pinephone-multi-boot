#!/bin/sh

L=`losetup -P --show -f "$1"`

mkdir -p m
mount ${L}p9 m
mount ${L}p4 m/boot
bsdtar -cvf - -C m --numeric-owner . | zstd -z -T0 -19 - > rootfs.tar.zst
umount m/boot
umount m

mount ${L}p6 m
bsdtar -cvf - -C m --numeric-owner . | zstd -z -T0 -19 - > recovery.tar.zst
umount m

losetup -d $L