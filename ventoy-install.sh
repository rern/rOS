#!/bin/bash

echo -e "\n\e[44m  \e[0m V e n t o y - A New Bootable USB Solution\n"

url=https://github.com/ventoy/Ventoy/releases
rel=$( curl -sL -o /dev/null -w %{url_effective} $url/latest | awk -F/ '{print $NF}' )
rel=${rel:1}

echo Latest version: $rel

curl -L $url/download/v$rel/ventoy-$rel-linux.tar.gz | bsdtar xf -
$PWD/ventoy-$rel/VentoyWeb.sh
