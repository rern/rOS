#!/bin/bash

echo -e "\n\e[44m  \e[0m V e n t o y - A New Bootable USB Solution\n"

https_ventoy=https://github.com/ventoy/Ventoy
latest=$( githubRepoLatest $https_ventoy )
name_ver=ventoy-${latest:1}
curl -sL $https_ventoy/releases/download/$latest/$name_ver-linux.tar.gz | bsdtar xf -
cd $name_ver
./VentoyWeb.sh
