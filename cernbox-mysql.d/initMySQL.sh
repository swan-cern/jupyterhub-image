#! /bin/bash


export DOCKER_NETWORK="initmysqlnet"
export DOCKER_COMPOSE_FILE="initMySQL.yaml"
export MYSQL_FOLDER="./mysql"
export LOCK_FILE="./cernbox.lock"


# Initialize folder for MySQL database and touch the lock file for CERNBox
mkdir $MYSQL_FOLDER
touch $LOCK_FILE

# Set up Docker network and containers
echo ""
echo "Creating and configuring containers..."
docker network create $DOCKER_NETWORK
docker-compose -f $DOCKER_COMPOSE_FILE up -d

# Wait for CERNBox to populate MySQL
count=0
while [ -f $LOCK_FILE ]; do
  sleep 5
  count=$((count+5))
  echo "    Waiting for setup to complete... ${count}s"
done
echo "    Completed!"

# Once done, kill the containers and delete the network
echo "Removing containers..."
docker-compose -f $DOCKER_COMPOSE_FILE down
docker network remove $DOCKER_NETWORK

# Make the tarball with MySQL files
echo "Creating tarball with pre-populated MySQL database..."
tar -zcf MySQL.tar.gz $MYSQL_FOLDER
rm -rf $MYSQL_FOLDER

echo ""
echo "Done." 
