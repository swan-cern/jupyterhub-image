#!/bin/bash

###
# This file is used to install at run-time a vanilla CERNBox to initialize a MySQL database.
###

# Install software required by CERNBox
echo ""
echo "Installing software required by CERNBox..."
yum -y install \
	git \
	php \
	rh-php70* \
        mariadb

# Clone CERNBox from Git
mkdir -p /var/www/html
cd /var/www/html && \
  git clone https://github.com/cernbox/core cernbox && \
  cd cernbox && \
  git checkout cernbox-prod-9.1.6 && \
  git submodule update --init

# Wait for the MySQL server to be ready
echo ""
echo "Wating for the MySQL server to be ready..." 
while ! mysqladmin ping --host="mysql.initmysqlnet" --user="$MYSQL_USER" --password="$MYSQL_PASSWORD"; do
  sleep 5
done

# Install CERNBox to initialize MySQL (MariaDB) running in the MySQL contianer
echo ""
echo "Installing CERNBox to init MariaDB backend...."
source /opt/rh/rh-php70/enable && \
  cd /var/www/html/cernbox && \
  rm -rf config/config.php && \
  ./occ maintenance:install --admin-user "_local" --admin-pass "_local" --database "mysql" --database-host "mysql.initmysqlnet" --database-user $MYSQL_USER --database-pass $MYSQL_PASSWORD --database-name $MYSQL_DATABASE --database-table-prefix "oc_" 

# Once the database is populated, remove the lock file and exit
rm -rf /hostPath/cernbox.lock

echo ""
echo "I am done!"
exit $?

