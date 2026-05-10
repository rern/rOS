#!/bin/bash

url=https://github.com/ventoy/Ventoy/releases
rel=$( curl -sL -o /dev/null -w %{url_effective} $url/latest | awk -F/ '{print $NF}' )
rel=${rel:1}
curl -L $url/download/v$rel/ventoy-$rel-linux.tar.gz | bsdtar xf -
cd ventoy-$rel
./VentoyWeb.sh
