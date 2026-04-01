#!/bin/bash

list=$( grep -B1 --no-group-separator -iE '^Info: *Configures.*(audio|dac|codec|i2s|sound)' /boot/overlays/README \
            | tail +3 \
            | sed -E '
                s/^Info: *Configures (the )*//
                s/ (audio|audio card|card|I2S overlay|sound *card)s*\.*$//
                s/ (add on|audio cards*|hat)//i
                s/^audioinjector.net/Audio Injector/
                s/^a(udiophonics)/A\1/
                s/^audiosense-pi/AudioSense-Pi/
                s/^dacberry/DacBerry/
                s/any passive/Generic/
                s/a generic/Generic (master)/
                s/^mbed.*/Mbed Audio Codec/
                s/^merus-amp/MERUS Amp/
                s/^pibell/PiBell/
                s/^ugreen.*/uGreen DABBoard/
            ' \
            | awk '{
                if ( $1 ~ /^Name:/ ) file = $2
                else print ", \""$0 "\": \"" file "\""
            }' )
echo '{ "(None / Auto detect)": ""'$list' }'
