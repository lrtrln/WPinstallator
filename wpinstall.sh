#!/bin/bash -e

# install https://gist.github.com/xavierartot/61f7e6d7ab1e6318a1d0

# Check wp-cli installed
type wp >/dev/null 2>&1 || { echo >&2 "This script requires wp-cli but it's not installed.  Aborting."; exit 1; }

# colors
blue="\033[34m"
red="\033[1;31m"
green="\033[32m"
white="\033[37m"
yellow="\033[33m"

echo -e "To install in a subfolder, write the folder name.\n"
echo -e "Otherwise leave empty to install in root:"
read -e folder

if [[ "$folder" != "" ]]; then
    mkdir $folder && cd $folder
else
    path_arg=""
fi

echo "============================================"
echo "WordPress Install Script"
echo "============================================"

echo -e "${blue}* Project name ${white}"
read -e pname
echo -e "${blue}* DB name ${white}"
read -e dbname
echo -e "${blue}* DB user ${white}"
read -e dbuser
echo -e "${blue}* DB password ${white}"
read -e dbpass
echo -e "${blue}* Language (default en_EN) ${white}"
read -e lang
echo -e "${blue}Run install? (y/n) ${white}"
read -e run

if [[ "$run" == n ]]; then
   exit
fi

wp core download --locale="$lang"

echo "Creating MYSQL stuff. MySQL admin password required."

MYSQL=`which mysql`

Q1="CREATE DATABASE IF NOT EXISTS $dbname;"
Q2="GRANT USAGE ON *.* TO $dbuser@localhost IDENTIFIED BY '$dbpass';"
Q3="GRANT ALL PRIVILEGES ON $dbname.* TO $dbuser@localhost;"
Q4="FLUSH PRIVILEGES;"

SQL="${Q1}${Q2}${Q3}${Q4}"
$MYSQL -uroot -p -e "$SQL"

echo -e "${green}* MYSQL done :) \n ${white}*"

echo "Running WP-CLI core config"
wp core config --dbname=$dbname --dbuser=$dbuser --dbpass=$dbpass --extra-php <<PHP
define( 'WP_DEBUG', true );
// Force display of errors and warnings
define( "WP_DEBUG_DISPLAY", true );
@ini_set( "display_errors", 1 );
// Enable Save Queries
define( "SAVEQUERIES", true );
// Use dev versions of core JS and CSS files (only needed if you are modifying these core files)
define( "SCRIPT_DEBUG", true );
PHP

echo -e "${blue}Site URL (without http://):${white}"
read -e siteurl

echo -e "${blue}Site title:${white}"
read -e sitetitle

echo -e "${blue}WP-admin User:${white}"
read -e adminuser

echo -e "${blue}WP-admin Password:${white}"
read -e adminpassword

echo -e "${blue}WP-admin Email:${white}"
read -e adminemail

echo -e "Running WP-CLI core install"
wp core install --url="http://$siteurl" --title="$sitetitle" --admin_user="$adminuser" --admin_password="$adminpassword" --admin_email="$adminemail"

echo -e "${green}* WP core install done :) \n ${white}*"


echo -e "Write wpcli config. \n"
cat >> wp-cli.yml <<EOL
apache_modules:
   - mod_rewrite
EOL

# set pretty urls
wp rewrite structure '/%postname%/' --hard
wp rewrite flush --hard

# Update WordPress options
wp option update timezone_string "Europe/Paris"
wp option update blog_public "off"
wp option update default_ping_status 'closed'
wp option update default_pingback_flag '0'
wp option update blogdescription "This is a new project!!"

# generate htaccess
wp rewrite flush --hard

wp plugin delete hello

echo -e "${green}* \n WP installing finished! \n "
echo -e "Now you can login as user you have chosen. Have fun! \n ${white}"