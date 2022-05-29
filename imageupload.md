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

# ? What account do you want to log into? 
#   > GitHub.com
# ? What is your preferred protocol for Git operations?
#   > SSH
# ? Upload your SSH public key to your GitHub account?
#   > /home/USER/.ssh/id_rsa.pub
# ? How would you like to authenticate GitHub CLI?
#   > Login with a web browser
```

- Clone repo
```sh
gh repo clone REPO
cd REPO
```

- Upload
```sh
gh release create VERSION ../PATH/*.tar.xz
```
