**Setup**
```sh
pacman -Sy github-cli
gh auth login # as root
	# ? What account do you want to log into? 
	#   » GitHub.com
	# ? What is your preferred protocol for Git operations on this host?
	#   » HTTPS
	# ? Authenticate Git with your GitHub credentials?
	#   » Y
	# ? How would you like to authenticate GitHub CLI?
	#   » Login with a web browser
	# ! First copy your one-time code: CODE-CODE
	# Press [Enter] to open https://github.com/login/device in your browser...
	#   » DO NOT 'Press Enter' yet
```
Manually open browser: https://github.com/login/device
- » Select user *(login if not already)*
- » Copy-paste the one-time code *(from terminal)* » `Authorize`
- » Enter verifying code *(by Authenticator app - if prompt)*

*Continue the terminal*
```sh
	#   > Press [Enter] (Ignore warning: Running Firefox as root ...)
	# ✓ Authentication complete.

# rAudio local repo - for upload
echo 'UUID=CCB4C52FB4C51D38  /mnt/BIG  ntfs  defaults,noatime 0 0' >> /etc/fstab
systemctl daemon-reload
mount -a
```
