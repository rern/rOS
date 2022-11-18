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
	gh auth login -p ssh

	# ? What account do you want to log into? 
	#   > GitHub.com
	# ? Upload your SSH public key to your GitHub account?
	#   > Skip
	# ? How would you like to authenticate GitHub CLI?
	#   > Paste an authentication token
	```
	- Get token: [Personal access token](https://github.com/settings/tokens) via github.com
- Upload [SSH keys](https://github.com/settings/keys) > `New SSH key` via github.com
	- Get key: `cat .ssh/id_rsa.pub`

- Clone repo
	```sh
	gh repo clone rern/rAudio-1
	```

- Upload
	```sh
	cd rAudio-1
	gh release create <VERSION> /<PATH>/*.img.xz
	```
