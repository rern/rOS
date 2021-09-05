### Country codes:
```sh
curl -sL https://git.kernel.org/pub/scm/linux/kernel/git/sforshee/wireless-regdb.git/plain/db.txt \
  | grep ^country \
  | cut -d' ' -f2 \
  | tr -d :
```
