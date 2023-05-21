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
	gh auth login -p ssh -w

	# ? What account do you want to log into? 
	#   > GitHub.com
	# ? Upload your SSH public key to your GitHub account?
	#   > Skip (if already)
	```
- Upload [SSH keys](https://github.com/settings/keys) > `New SSH key` via github.com
	- Get key: `cat .ssh/id_rsa.pub`

- Clone repo
	```sh
	gh repo clone rern/rAudio
	```

- Upload
	```sh
	cd rAudio
	gh release create <VERSION> /<PATH>/*.img.xz
	```
