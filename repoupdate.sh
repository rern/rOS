#!/bin/bash

rm $0

updateRepo() {
	# recreate database
	cd /mnt/Git/rern.github.io/$1
	rm RR*
	repo-add -R RR.db.tar.xz *.xz
	
	# index.html
	html='<!DOCTYPE html>
<html>
<head>
	<meta charset="utf-8">
	<title>R+R Packages</title>
	<style>
		table { font-family: monospace; white-space: pre; border: none }
		td:last-child { padding-left: 10px; text-align: right }
	</style>
</head>
<body>
<table>
	<tr><td><a href="/">../</a></td><td></td></tr>'
	pkg=( $( ls *.pkg.tar.xz ) )
	readarray -t sizedate <<<$( ls -lh *.pkg.tar.xz | cut -c24-40 )
	pkgL=${#pkg[@]}
	for (( i=1; i < $pkgL; i++ )); do
		pkg=${pkg[$i]}
		html+='
	<tr><td><a href="'$1'/'$pkg'">'$pkg'</a></td><td>'${sizedate[$i]}'</td></tr>'
	done
	html+='
<table>
</body>
</html>'

	echo -e "$html" > ../$1.html
}

arch=$( dialog --colors --output-fd 1 --checklist '\n\Z1Arch:\Z0' 8 30 0 \
	1 armv6h on \
	2 armv7h on )
arch=" $arch "
[[ $arch == *' 1 '* ]] && armv6h='armv6h '
[[ $arch == *' 2 '* ]] && armv7h='armv7h '
if [[ -z $armv6h && -z $armv7h ]]; then
	dialog --colors --msgbox '\nNo \Z1Arch\Z0 selected.' 8 30
	exit
fi

ip=$( dialog --colors --output-fd 1 --inputbox "\n\Z1Local Git IP:\Z0" 10 30 192.168.1.9 )

clear

mkdir -p /mnt/Git
mount -t cifs -o password= //$ip/Git /mnt/Git
if [[ $? == 1 ]]; then
	dialog --colors --msgbox "\nMount \Z1$ip\Z0 failed." 8 30
	exit
fi

currentdir=$( pwd )

[[ $armv6h ]] && updateRepo armv6h
[[ $armv7h ]] && updateRepo armv7h

cd "$currentdir"
umount -l /mnt/Git
rmdir /mnt/Git

dialog --colors --msgbox "\n\Z1$armv6h$armv7h\Z0repo\nupdated succesfully." 8 30
