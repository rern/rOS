### Country codes:
```sh
curl -sL https://github.com/EXSERENS/wireless-regdb/raw/regfree/db.txt \
  | grep ^country \
  | cut -d' ' -f2 \
  | tr -d :
```
