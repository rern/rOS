### Country codes:
```sh
codes=$( curl -sL https://git.kernel.org/pub/scm/linux/kernel/git/sforshee/wireless-regdb.git/plain/db.txt \
  | grep ^country \
  | cut -d' ' -f2 \
  | tr -d : )
  
iso3166=$( curl -sL https://gist.github.com/ssskip/5a94bfcd2835bf1dea52/raw/3b2e5355eb49336f0c6bc0060c05d927c2d1e004/ISO3166-1.alpha2.json \
			| sort \
			| head -n -2 )

isokeys=$( echo "$iso3166list" | sed 's/^.*"\(.*\)":.*/\1/' )

for k in $isokeys; do
	grep -q $k <<< "$codes" || iso3166=$( grep -v $k <<< "$iso3166" )
done

regdomcodes='"00": "00 - Generic",'
regdomcodes+=$iso3166

echo {$regdomcodes} | jq . > regdomcodes.json
```
