#!/bin/bash

echo -e "\n\e[44m  \e[0m V e n t o y - A New Bootable USB Solution\n"

url=https://github.com/ventoy/Ventoy/releases
latest=$( curl -sL -o /dev/null -w %{url_effective} $url/latest | awk -F/ '{print $NF}' )
name_ver=ventoy-${latest:1}
curl -sL $url/download/$latest/$name_ver-linux.tar.gz | bsdtar xf -
cd $name_ver
./VentoyWeb.sh
