# WP Auto Install
The purpose of this bash script is to automate every aspect of getting a Wordpress instance up and running.

## What This Script Does

This bash script performs the following tasks in this order:

1. Downloads the latest version of Wordpress
2. Untars the file and moves the folder to the install directory
3. Renames the Wordpress folder to the domain name
4. Renames <domain-name>/wp-config-sample.php to wp-config.php
5. Sets the database credentials in wp-config.php
6. Adds a virtual host record to the Apache vhosts conf file
7. Creates a database and administrative user for the website

## Dependencies

This script uses the Secure Delete utility to clean up temporary files.

## Usage


## Tested

Known to work on AWS EC2 instances with RDS or MySQL on localhost. 
