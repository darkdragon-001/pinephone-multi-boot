#!/bin/sh

if [ "$(whoami)" != "root" ] ; then
	exec sudo sh "$0" "$@"
fi

# loglevel=15
serial="console=ttyGS0"
#serial="console=ttyS0,115200 earlycon=ns16550a,mmio32,0x01c28000"
silent="quiet loglevel=0 systemd.show_status=false"
bootargs_base="$serial $silent cma=256M console=tty1 consoleblank=0 panic=3 rw rootwait root=PARTUUID=12345678-02 rootfstype=btrfs rootflags=compress-force=zstd,nodatacow,subvol"
kbuilds=../builds

(
	echo "device_id = Distro Demo Image 0.2beta"
	no=0
	for ddir in distros/*
	do
		dist=${ddir#distros/}

		(
			source ./$ddir/config
			
			echo "no = $no"
			echo "  name = $name $version"
			echo "  atf = ../p-boot/dist/fw.bin"
			echo "  dtb = $kbuilds/ppd-5.9/board-1.1.dtb"
			echo "  dtb2 = $kbuilds/ppd-5.9/board-1.2.dtb"
			echo "  linux = $kbuilds/ppd-5.9/Image"
			echo "  bootargs = $bootargs_base=$dist $bootargs"
			echo "  splash = files/$dist.argb"
		)

		no=$(($no+1))
	done
) > boot.conf

set -e -x

L=`losetup -P --show -f multi.img`
../p-boot/.build/p-boot-conf-native . ${L}p1
../p-boot/.build/p-boot-conf-native . boot-part.img
losetup -d $L

dd if=../p-boot/.build/p-boot.bin of=multi.img bs=1024 seek=8 conv=notrunc
