Setup
---
```sh
su
pacman -Sy github-cli

su x
cd
gh auth status
# login if not yet
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
# setup
git config --global user.email EMAIL
git config --global user.name NAME
ln -s BIG/RPi/Git/rAudio .
```
