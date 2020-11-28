#!/bin/bash

if [ "$(whoami)" != "root" ] ; then
	exec sudo sh "$0" "$@"
fi

source ./config

# loglevel=15
serial="console=ttyS0,115200 earlycon=ns16550a,mmio32,0x01c28000"
silent="quiet loglevel=0 systemd.show_status=false"
bootargs_base="$serial $silent cma=256M console=tty1 consoleblank=0 panic=3 rw rootwait root=PARTUUID=12345678-02 rootfstype=btrfs rootflags=compress-force=zstd,nodatacow,subvol"
kbuilds=../builds
pboot=../p-boot/dist

echo "device_id = $DEVICE_ID" > boot.conf

no=0
for ddir in distros/*
do
	test -f $ddir/config || continue
	dist=${ddir#distros/}

	(
		source ./$ddir/config
			
		echo "no = $no"
		echo "  name = $name $version"
		echo "  atf = ../p-boot/dist/fw.bin"
		echo "  dtb = $kbuilds/ppd-5.10/board-1.1.dtb"
		echo "  dtb2 = $kbuilds/ppd-5.10/board-1.2.dtb"
		echo "  linux = $kbuilds/ppd-5.10/Image"
		echo "  bootargs = $bootargs_base=$dist $bootargs"
		echo "  splash = files/$dist.argb"
	) >> boot.conf

	no=$(($no+1))
done

# JumpDrive is special
if test -d distros/jumpdrive
then
	(
		echo "no = $no"
		echo "  name = Jumpdrive 0.6"
		echo "  atf = ../p-boot/dist/fw.bin"
#		echo "  dtb = distros/jumpdrive/sun50i-a64-pinephone-1.1.dtb"
#		echo "  dtb2 = distros/jumpdrive/sun50i-a64-pinephone-1.2.dtb"
#		echo "  linux = distros/jumpdrive/Image"
		echo "  dtb = $kbuilds/ppd-5.10/board-1.1.dtb"
		echo "  dtb2 = $kbuilds/ppd-5.10/board-1.2.dtb"
		echo "  linux = $kbuilds/ppd-5.10/Image"
		echo "  initramfs = distros/jumpdrive/initramfs"
		echo "  bootargs = loglevel=0 silent console=tty0 vt.global_cursor_default=0"
		echo "  splash = files/jumpdrive.argb"
	) >> boot.conf

	no=$(($no+1))
fi

set -e -x

L=`losetup -P --show -f $IMG`
$pboot/p-boot-conf-native . ${L}p1
#$pboot/p-boot-conf-native . boot-part.img
losetup -d $L

dd if=$pboot/p-boot.bin of=$IMG bs=1024 seek=8 conv=notrunc
