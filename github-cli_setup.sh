#/bin/bash

color() {
	[[ ${1:0:1} == '(' ]] && c=7 || c=10
	echo "\e[38;5;${c}m$1\e[0m"
}
tick=$( color ✓ )
dot=$( color » )
code=$( color CODE-CODE )
bar "gh auth login:

? What account do you want to log into?
	$tick GitHub.com
? What is your preferred protocol for Git operations on this host?
    $tick HTTPS
? Authenticate Git with your GitHub credentials?
    $tick Y
? How would you like to authenticate GitHub CLI?
    $tick Login with a web browser
! First copy your one-time code: $code
    $dot Copy $code
Press [Enter] to open https://github.com/login/device in your browser...
    $dot Do not 'Press Enter' yet
$dot Manually open browser: https://github.com/login/device
    $dot Select user $( color '(login if not already)' )
    $dot Paste the copied code $( color '(from terminal)' ) » Authorize
    $dot Enter verifying code $( color '(by Authenticator app - if prompt)' )
» Press [Enter] (Ignore warning: Running Firefox as root ...)
    $dot Ignore error message

$tick Authentication complete.
"

gh auth login
email=$( dialog.input 'GitHub email:' )
user=$( dialog.input 'GitHub username:' )
git config --global user.email $email
git config --global user.name $user
