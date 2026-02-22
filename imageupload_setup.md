**Setup**
```sh
pacman -Sy github-cli
gh auth login
	# ? What account do you want to log into? 
	#   > GitHub.com
	# ? What is your preferred protocol for Git operations on this host?
	#   > HTTPS
	# ? Authenticate Git with your GitHub credentials?
	#   > Y
	# ? How would you like to authenticate GitHub CLI?
	#   > Login with a web browser
	# ! First copy your one-time code: CODE-CODE
	# Press Enter to open https://github.com/login/device in your browser...
	#   > DO NOT 'Press Enter' yet
```
Manually open browser: https://github.com/login/device
- Select user *(Login if not already)*
- Copy-paste the one-time code *(from terminal)*
- Enter verifying code *(by Authenticator app)*
- Success: ✓ Your device is now connected.

*Continue the terminal*
```sh
	#   > Press Enter (Ignore warning: Running Firefox as root ...)
	# ✓ Authentication complete.
git config --global user.email rernrern@gmail.com
git config --global user.name rern
```
