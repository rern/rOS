#/bin/bash

bar 'gh auth login:
? What account do you want to log into?
	» GitHub.com
? What is your preferred protocol for Git operations on this host?
	» HTTPS
? Authenticate Git with your GitHub credentials?
	» Y
? How would you like to authenticate GitHub CLI?
	» Login with a web browser
! First copy your one-time code: CODE-CODE
	» Copy the code
Press [Enter] to open https://github.com/login/device in your browser...
	» Do not 'Press Enter' yet
» Manually open browser: https://github.com/login/device
	» Select user (login if not already)
	» Paste the copied code (from terminal) » `Authorize`
	» Enter verifying code (by Authenticator app - if prompt)
» Press [Enter] (Ignore warning: Running Firefox as root ...)
✓ Authentication complete.
'
gh auth login
email=$( dialog.input 'GitHub email:' )
user=$( dialog.input 'GitHub username:' )
git config --global user.email $email
git config --global user.name $user
