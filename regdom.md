### Regulatory Domain Codes - `regdom.json`

- Fetch [regdom codes](https://git.kernel.org/pub/scm/linux/kernel/git/sforshee/wireless-regdb.git/)
	- Get only `country` codes
- Fetch [ISO 3166-1 country codes](https://gist.github.com/vxnick/380904/)
	- `\'` > `^`
	- `'` > `"`
	- `^` > `'`
- Create `regdom.json`
```sh
regdomlist=( $( wget -qO- https://git.kernel.org/pub/scm/linux/kernel/git/sforshee/wireless-regdb.git/plain/db.txt \
    | awk -F '[ :]' '/^country/ {print $2}' ) )

isolist=$( wget -qO- https://gist.github.com/vxnick/380904/raw/464e508a59a16e0d2aa62e2817eab820972f196c/gistfile1.php \
    | sed "s/\\\'/^/" \
	| tr "'" '"' \
	| tr '^' "'" )

for code in "${regdomlist[@]}"; do
    country=$( grep "^\s*\"$code" <<< "$isolist" | cut -d\" -f4 )
    [[ -n $country ]] && codes+='
    , "'$country'": "'$code'"'
done

regdom=$( echo "$codes" | sort )

regdom='"(Generic / World)": "00"'$regdom

echo {$regdom} | jq . > regdom.json
```
