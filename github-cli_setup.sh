#/bin/bash

color() {
	echo "\e[38;5;10m$@\e[0m"
}
dot=$( color » )
code=$( color CODE-CODE )
url=https://github.com/login/device
banner gh auth login
echo -e "\
? Where do you use GitHub?
    $( color GitHub.com )
? What is your preferred protocol for Git operations on this host?
    $( color HTTPS )
? How would you like to authenticate GitHub CLI?
    $( color Login with a web browser )
! First copy your one-time code: $code
Press [Enter] to open $url in your browser...
    Do not 'Press Enter' yet
    $dot Copy $code
$dot Manually open browser: $url
    $dot Select user (login if not already)
    $dot Paste $code
	$dot Authorize
    $dot Enter verifying code (by Authenticator app - if prompt)
» Press [Enter]
	Ignore warning: Running Firefox as root ...

$( color ✓ ) Authentication complete.
................................................................................
"

gh auth login
email=$( dialog.input 'GitHub email:' )
user=$( dialog.input 'GitHub username:' )
git config --global user.email $email
git config --global user.name $user
