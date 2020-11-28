#!/bin/bash

if [ "$(whoami)" != "root" ] ; then
	exec sudo bash "$0" "$@"
fi

PASS='$6$nzZZGV65imLStmVz$u/Z1litGJh5tV2NmvzeirBiPkwWmhD0CQ.xRzdOV26vMxURbQUDW8Nkss8mvYVzwQ5SnwvGV/.ttSG0Kmrg.L/'

for ddir in distros/*
do
	test -f $ddir/config || continue
	name=${ddir#distros/}
	mdir=m/$name

	mkdir -p m/.pristine
	test -d m/.pristine/$name || btrfs subvolume snapshot $mdir m/.pristine/$name

	echo "Patching $name..."

	btrfs subvolume delete $mdir
	btrfs subvolume delete m/.pre-boot/$name
	btrfs subvolume snapshot m/.pristine/$name $mdir

	(
		cd $mdir || exit
		ddir="../../$ddir"

		sed -i '/mmcblk\|UUID\|LABEL/d' etc/fstab
		sed -i "s#\$6\$.*#$PASS:::::::#" etc/shadow
		sed -i "s#\$1\$.*#$PASS:::::::#" etc/shadow
		sed -i "s#^root:.*#root:$PASS:::::::#" etc/shadow

		mkdir -p etc/systemd/journald.conf.d
		cat <<EOF > etc/systemd/journald.conf.d/xnux.conf
[Journal]
Storage=none
EOF

		cat <<EOF > etc/machine-info
PRETTY_HOSTNAME="PINE64 PinePhone"
CHASSIS="handset"
EOF

		if [ $name = ut ] ; then
			mkdir -p android/{cache,data,factory,firmware,odm,persist,system{,/vendor}}
			touch userdata/.writable_image

		fi

		while IFS= read -r -d $'\0' src
		do
			dst="${src#$ddir/overrides/}"
			echo Fixing "$dst"
			test -f "$dst" && {
				chattr -i "$dst"
				test -f "$dst.orig" || cp "$dst" "$dst.orig"
			}
			mkdir -p "$(dirname "$dst")"
			cat "$src" > "$dst"
			chattr +i "$dst"
		done < <(find "$ddir/overrides" -type f -print0)
	)

	mkdir -p m/.pre-boot
	test -d m/.pre-boot/$name || btrfs subvolume snapshot $mdir m/.pre-boot/$name
done
