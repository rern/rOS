Image Files Upload
---
- Install `github-cli`
```sh
su
pacman -Sy github-cli
```

- Login
```sh
su USER
cd
# create ssh key
ssh-keygen

# login
gh auth login

# > Protocol: SSH
# > Public key: upload
# > Authenticate: Token
```

- Clone repo
```sh
gh repo clone REPO
cd REPO
```

- Upload
```sh
gh release create VERSION PATH/*.tar.xz
```
