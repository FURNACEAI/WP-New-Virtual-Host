#!/usr/bin/env bash

# Load the config file
. ./.config

# command -v srm >/dev/null 2>&1 || { echo >&2 "I require the Secure Delete utility but it's not installed. Aborting."; exit 1;
if [[ $# -eq 0 ]] ; then
    echo 'You must provide a domain name for this script to run.'
    exit 0
fi

while getopts d:a:i:v:h:u: option
do
 case "${option}"
 in
 d) DOMAIN=${OPTARG};;
 a) SERVER_ALIAS=${OPTARG};;
 i) INSTALL_PATH=${OPTARG};;
 v) VHOST_FILE=${OPTARG};;
 h) DB_HOST=${OPTARG};;
 u) DB_ROOT_USR=$OPTARG;;
 esac
done

INSTALL_DIR=$INSTALL_PATH$DOMAIN
SQL_FILE="tmp.sql"
WPSRC="wordpress"

echo "================================"
echo ""
echo "DOMAIN: $DOMAIN"
echo "INSTALL PATH: $INSTALL_PATH"
echo "VHOST: $VHOST_FILE"
echo "DB HOST: $DB_HOST"
echo "DB ROOT USER: $DB_ROOT_USR"
echo ""
echo "================================"
echo ""
echo "Wordpress will be installed in $INSTALL_DIR"
echo ""
echo "================================"
echo ""
echo "You Are running: "
lsb_release -irc
echo ""
echo "================================"
echo ""
echo "DEBUGGING: "
echo $INSTALL_PATH$WPSRC
echo ""
echo "================================"


# GENERATE KEYS & DB VARS
DOMAIN_LABEL=${DOMAIN//.}
DB_NEW_PWD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# FETCH LATEST WORDPRESS
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
rm latest.tar.gz
mv wordpress $INSTALL_PATH
mv $INSTALL_PATH$WPSRC $INSTALL_DIR

# UPDATE OWNERS AND PERMISSIONS
sudo chown bitnami:daemon -R $INSTALL_DIR
sudo find . -type d -exec chmod 755 {} \;  # Change directory permissions rwxr-xr-x
sudo find . -type f -exec chmod 644 {} \;  # Change file permissions rw-r--r--

# CONFIGURE WORDPRESS
mv $INSTALL_DIR/wp-config-sample.php $INSTALL_DIR/wp-config.php
sed -i "/DB_HOST/s/'[^']*'/'$DB_HOST'/2" $INSTALL_DIR/wp-config.php
sed -i "/DB_NAME/s/'[^']*'/'$DOMAIN_LABEL'/2" $INSTALL_DIR/wp-config.php
sed -i "/DB_USER/s/'[^']*'/'$DOMAIN_LABEL-admin'/2" $INSTALL_DIR/wp-config.php
sed -i "/DB_PASSWORD/s/'[^']*'/'$DB_NEW_PWD'/2" $INSTALL_DIR/wp-config.php

# ADD THE VIRTUAL HOST RECORD
cat <<EOT >> "$VHOST_FILE"

# $DOMAIN
<VirtualHost *:80>
    ServerAdmin webmaster@$DOMAIN
    DocumentRoot "$INSTALL_DIR"
    ServerName www.$DOMAIN
    ServerAlias $DOMAIN
    ErrorLog "logs/$DOMAIN-error_log"
    CustomLog "logs/$DOMAIN-access_log" common
    <Directory "$INSTALL_DIR">
        # AllowOverride All      # Deprecated
        # Order Allow,Deny       # Deprecated
        # Allow from all         # Deprecated

        # --New way of doing it
        Require all granted
    </Directory>
</VirtualHost>

EOT

# Create a SQL file for creating new DB user and WP database. Grant the user all privilages on the db.
cat <<EOT >> "./$SQL_FILE"
CREATE USER '$DOMAIN_LABEL-admin'@'$DB_HOST' IDENTIFIED BY '$DB_NEW_PWD';
CREATE DATABASE `$DOMAIN_LABEL`
GRANT ALL PRIVILEGES ON `$DOMAIN_LABEL`.* TO "$DOMAIN_LABEL-admin"@"$DB_HOST";
FLUSH PRIVILEGES;
exit;
EOT

# Run the above SQL file
mysql -h $DB_HOST -u $DB_ROOT_USR -p$DB_ROOT_PWD < $SQL_FILE
# Trash the SQL file with secure delete
sudo srm "./$SQL_FILE"

# RESTART APACHE
sudo apachectl restart

echo "$DOMAIN is configured and ready for viewing."
