#!/usr/bin/env bash

# Load the config file
. ./settings.conf

# command -v srm >/dev/null 2>&1 || { printf >&2 "I require the Secure Delete utility but it's not installed. Aborting."; exit 1;
if [[ $# -eq 0 ]] ; then
    printf 'You must provide a domain name for this script to run.'
    exit 0
fi

while getopts d:a: option
do
 case "${option}"
 in
 d) DOMAIN=${OPTARG};;
 a) SERVER_ALIAS=${OPTARG};;
 esac
done

INSTALL_DIR=$INSTALL_PATH$DOMAIN
SQL_FILE="tmp.sql"
WPSRC="wordpress"

# GENERATE KEYS & DB VARS
DOMAIN_LABEL=${DOMAIN//.}
DB_NEW_NAME=${DOMAIN_LABEL:0:64}
DB_NEW_USR="admin-$DOMAIN_LABEL"
DB_NEW_USR=${DB_NEW_USR:0:16}
DB_NEW_PWD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

printf "================================\n\n"
printf "DOMAIN: $DOMAIN \n"
printf "INSTALL PATH: $INSTALL_PATH \n"
printf "VHOST: $VHOST_FILE \n"
printf "DB HOST: $DB_HOST \n"
printf "DB ROOT USER: $DB_ROOT_USR \n"
printf "NEW DB USER: $DB_NEW_USR \n"
printf "NEW DB NAME: $DB_NEW_NAME \n"
printf "\n================================\n"
printf "Wordpress will be installed in $INSTALL_DIR \n"
printf "\n================================\n"
printf "You Are running: \n"
lsb_release -irc
printf "\n================================\n\n"

# FETCH LATEST WORDPRESS
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
rm latest.tar.gz
mv wordpress $INSTALL_PATH
mv $INSTALL_PATH$WPSRC $INSTALL_DIR

# UPDATE OWNERS AND PERMISSIONS
chown bitnami:daemon -R $INSTALL_DIR
find . -type d -exec chmod 755 {} \;  # Change directory permissions rwxr-xr-x
find . -type f -exec chmod 644 {} \;  # Change file permissions rw-r--r--

# CONFIGURE WORDPRESS
mv $INSTALL_DIR/wp-config-sample.php $INSTALL_DIR/wp-config.php
sed -i "/DB_HOST/s/'[^']*'/'$DB_HOST'/2" $INSTALL_DIR/wp-config.php
sed -i "/DB_NAME/s/'[^']*'/'$DOMAIN_LABEL'/2" $INSTALL_DIR/wp-config.php
sed -i "/DB_USER/s/'[^']*'/'$DB_NEW_USR'/2" $INSTALL_DIR/wp-config.php
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
CREATE USER '$DB_NEW_USR'@'$DB_HOST' IDENTIFIED BY '$DB_NEW_PWD';
CREATE DATABASE \`$DB_NEW_NAME\`
GRANT ALL PRIVILEGES ON \`$DB_NEW_NAME\`.* TO "$DB_NEW_USR"@"$DB_HOST";
FLUSH PRIVILEGES;
exit;
EOT

# Run the above SQL file
mysql -h $DB_HOST -u $DB_ROOT_USR -p < $SQL_FILE
# Trash the SQL file with secure delete
sudo srm "./$SQL_FILE"

# RESTART APACHE
apachectl restart

printf "\n$DOMAIN is configured and ready for viewing.\n"
