#!/bin/bash
# Configure the local host

### VARIABLES ###
DOCKER_NETWORK_NAME="demonet"

CVMFS_FOLDER="/tmp/SWAN-in-Docker/cvmfs_mount"
EOS_FOLDER="/tmp/SWAN-in-Docker/eos_mount"

EOSSTORAGE_HEADING="eos-"
EOSSTORAGE_FST_AMOUNT=6
EOSSTORAGE_MGM="mgm"
EOSSTORAGE_MQ="mq"
EOSSTORAGE_FST_NAME="fst"

OPENLDAP_DB_VOLUME="openldap_database"
OPENLDAP_CF_VOLUME="openldap_config"



# ----- Preliminary Checks ----- # 
# Check to have certificates for serving JupyterHub over TLS
if [[ -f secrets/jupyterhub.crt && -f secrets/jupyterhub.key ]]; then
	echo "I have secrets for SSL."
else
	echo "Need a SSL key and certificate in secrets/jupyterhub.{key,crt}"
	exit 1
fi

# Check to have an admins list for JupyterHub
if [[ -f jupyterhub.d/adminslist ]]; then
	echo "I have the userlist."
else
	echo "Need usernames for admins, one per line, to jupyterhub.d/adminslist"
	exit 1
fi
echo "All fine. Continuing..."
echo ""


# ----- Clean up and preparation ----- #
# Raise warning about CVMFS and EOS before continuing
echo ""
echo "WARNING: The deployment interferes with eventual CVMFS and EOS clients running on the host."
echo "All the running clients will be killed before proceeding."
read -r -p "Do you want to continue [y/N] " response
case "$response" in
    [yY]) 
	echo "Ok."
        ;;
    *)
        echo "Aborted."
        exit
        ;;
esac

# Clean up the (eventual) previous deployment
# WARNING: This is not going to work if there is a user server still running: it keeps CVMFS and EOS locked
echo ""
echo "Cleaning up..."
# TODO: CERNBox Containers should be added to the list
docker stop jupyterhub openldap openldap-ldapadd cvmfs eos-fuse cernbox cernboxgateway 2>/dev/null
docker rm -f jupyterhub openldap openldap-ldapadd cvmfs eos-fuse cernbox cernboxgateway 2>/dev/null

# Note: Containers for eos server are not managed by docker-compose. They need to be stopped and removed here.
docker stop eos-fst{1..6} eos-mq eos-mgm 2>/dev/null
docker rm -f eos-fst{1..6} eos-mq eos-mgm eos-controller 2>/dev/null

# Remove CMVFS and EOS processes together with related folder for the mount
killall cvmfs2 2>/dev/null
killall eos 2>/dev/null
sleep 1
for i in `ls $CVMFS_FOLDER`
do
	fusermount -u $CVMFS_FOLDER/$i
	#umount -l $CVMFS_FOLDER/$i
done
fusermount -u $EOS_FOLDER
sleep 1
rm -rf /tmp/SWAN-in-Docker/ 2>/dev/null
rmdir /tmp/SWAN-in-Docker 2>/dev/null
echo "Cleaned."

# Continuing...
mkdir -p /tmp/SWAN-in-Docker
touch /tmp/SWAN-in-Docker/DO_NOT_WRITE_ANY_FILE_HERE
echo ""
echo "Continuing with the deployment..."


# ----- Check to have (or create) a Docker network to allow communications among containers ----- #
echo ""
echo "Setting up the Docker network: "$DOCKER_NETWORK_NAME
docker network inspect $DOCKER_NETWORK_NAME >/dev/null 2>&1 || docker network create $DOCKER_NETWORK_NAME
docker network inspect $DOCKER_NETWORK_NAME


# ----- Check to have (or pull) the CERN Jupyter notobook server image
# See: https://github.com/cernphsft/systemuser
echo ""
echo "Pulling Single-User-'s notebook image..."
NB_IMAGES=(cernphsft/systemuser:v2.9) # , jupyter/minimal-notebook)
for i in ${NB_IMAGES[*]};
do
	echo "Pulling $i..."
	docker pull $i
	echo ""
done


# ----- EOS STORAGE configuration ----- #
# Build the image for eos-storage
echo ""
echo "Building the Docker image for EOS components..."
docker build -t eos-storage -f eos-storage.Dockerfile .

echo ""
echo "Setting up external volumes for EOS..."
EOS_MGM=$EOSSTORAGE_HEADING$EOSSTORAGE_MGM
EOS_MQ=$EOSSTORAGE_HEADING$EOSSTORAGE_MQ
docker volume inspect $EOS_MQ >/dev/null 2>&1 || docker volume create --name $EOS_MQ
docker volume inspect $EOS_MGM >/dev/null 2>&1 || docker volume create --name $EOS_MGM
for i in {1..6}
do
    EOS_FST=$EOSSTORAGE_HEADING$EOSSTORAGE_FST_NAME$i
    docker volume inspect $EOS_FST >/dev/null 2>&1 || docker volume create --name $EOS_FST
done


# THIS IS NOT GOING TO WORK AS WE NEED LDAP TO RETRIEVE ADMIN INFO BUT LDAP IS NOT READY YES AT THIS STAGE
# We resort to the controller container that manages EOS storage deployment and dies  right after.
# It is possible to uncomment this part and forget about the controller container if LDAP is always-on
# or an external LDAP is used
: '
# Check to have (or create) volumes for EOS data and metadata, i.e., make storage persistent
echo ""
echo "Setting up EOS storage..."
EOS_MGM=$EOSSTORAGE_HEADING$EOSSTORAGE_MGM
EOS_MQ=$EOSSTORAGE_HEADING$EOSSTORAGE_MQ

# Set up EOS containers to achieve specific roles, e.g., MGM, MQ, FST.
echo "Instantiating MQ node..."
docker volume inspect $EOS_MQ >/dev/null 2>&1 || docker volume create --name $EOS_MQ
docker run -di --hostname $EOS_MQ.demonet --name $EOS_MQ --net=demonet eos-storage
docker exec -i $EOS_MQ bash /eos_mq_setup.sh

echo "Instantiating MGM node..."
docker volume inspect $EOS_MGM >/dev/null 2>&1 || docker volume create --name $EOS_MGM
docker run -di --hostname $EOS_MGM.demonet --name $EOS_MGM --net=demonet eos-storage
docker exec -i $EOS_MGM bash /eos_mgm_setup.sh

echo "Instantiating FST nodes..."
for i in {1..6}
do   
    EOS_FST=$EOSSTORAGE_HEADING$EOSSTORAGE_FST_NAME$i
    docker volume inspect $EOS_FST >/dev/null 2>&1 || docker volume create --name $EOS_FST
    docker run --privileged -di --hostname $EOS_FST.demonet --name $EOS_FST --net=demonet eos-storage
    docker exec -i $EOS_FST bash /eos_fst_setup.sh $i
done

echo "Configuring the MGM node..."
echo "\t --> Booting the FS..."
docker exec -i $EOS_MGM bash /eos_mgm_fs_setup.sh

echo "\t --> Installing and running nscd and nslcd services..."
docker exec -i $EOS_MGM yum -y install nscd nss-pam-ldapd
docker cp ./ldappam.d/nscd.conf $EOS_MGM:/etc
docker cp ./ldappam.d/nslcd.conf $EOS_MGM:/etc
docker cp ./ldappam.d/nsswitch.conf $EOS_MGM:/etc

docker exec -i $EOS_MGM nscd
docker exec -i $EOS_MGM nslcd 

echo "\t --> Configuring the EOS namespace..."
docker cp eos-storage/configure_eos_namespace.sh $EOS_MGM:/configure_eos_namespace.sh
docker exec -i $EOS_MGM bash /configure_eos_namespace.sh
'

# ----- Check to have (or create) a volume for OpenLDAP server, i.e., make users DB persistent ----- #
echo ""
echo "Setting up the Docker volumes for OpenLDAP: "$OPENLDAP_DB_VOLUME $OPENLDAP_CF_VOLUME
docker volume inspect $OPENLDAP_DB_VOLUME >/dev/null 2>&1 || docker volume create --name $OPENLDAP_DB_VOLUME
docker volume inspect $OPENLDAP_CF_VOLUME >/dev/null 2>&1 || docker volume create --name $OPENLDAP_CF_VOLUME


# ----- Clone the GitLab repository with CERN customizations for JupyterHub ----- #
echo ""
echo "Fetching CERN customizations..." 
git clone https://:@gitlab.cern.ch:8443/dmaas/jupyterhub.git jupyterhub.d/jupyterhub-dmaas 2>/dev/null
git clone https://:@gitlab.cern.ch:8443/ai/it-puppet-hostgroup-dmaas.git jupyterhub.d/jupyterhub-puppet 2>/dev/null


# ----- Set the locks for controlling the dependencies and execution order ----- #
echo ""
echo "Setting up locks..."
echo "Locking EOS-Storage -- Needs LDAP"
touch /tmp/SWAN-in-Docker/eos-storage-lock
echo "Locking eos-fuse client -- Needs EOS storage"
touch /tmp/SWAN-in-Docker/eos-fuse-lock

# ----- Updating hostname for cernbox ----
sed -e "s/%%%HOSTNAME%%%/`hostname --fqdn`/" cernbox.d/cernbox.config.template > cernbox.d/cernbox.config

# ----- Build and run via Docker Compose ----- #
echo ""
echo "Build and run"
docker-compose build
docker-compose up -d
docker-compose logs -f
