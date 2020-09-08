#!/bin/bash

PASS='$6$nzZZGV65imLStmVz$u/Z1litGJh5tV2NmvzeirBiPkwWmhD0CQ.xRzdOV26vMxURbQUDW8Nkss8mvYVzwQ5SnwvGV/.ttSG0Kmrg.L/'

for mdir in m/*
do
	dist=${mdir#m/}
	ddir="../../distros/$dist"

	(
		cd $mdir || exit

		sed -i '/mmcblk\|UUID/d' etc/fstab
		sed -i "s#\$6\$.*#$PASS:::::::#" etc/shadow
		sed -i "s#^root:.*#root:$PASS:::::::#" etc/shadow

		while IFS= read -r -d $'\0' src
		do
			dst="${src#$ddir/overrides/}"
			chattr -i "$dst"
			cat "$src" > "$dst"
			chattr +i "$dst"
		done < <(find "$ddir/overrides" -type f -print0)		
	)
done
