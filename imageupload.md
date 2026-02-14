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
gh auth login

# ? What account do you want to log into? 
#   > GitHub.com
# ? What is your preferred protocol for Git operations on this host?
#   > HTTPS
# ? Authenticate Git with your GitHub credentials?
#   > Yes
# ? How would you like to authenticate GitHub CLI?
#   > Login with a web browser
# ! First copy your one-time code: CODE-CODE
# Press Enter to open https://github.com/login/device in your browser...
#   > (enter)
### Browser
#     > enter CODE-CODE
#	  > verify with Authenticator app
# ✓ Authentication complete.
# git config --global user.email EMAIL
# git config --global user.name NAME
```

- Clone repo
	```sh
	gh repo clone rern/rAudio
	```

- Upload
	```sh
	cd rAudio
	gh release create <VERSION> /<PATH>/*.img.xz
	```
