#!/bin/bash
# Configure the local host starting from Docker files and having access to CERN GitLab


# ----- Variables ----- #

# Network
DOCKER_NETWORK_NAME="demonet"
export BOX_HOSTNAME=`hostname --fqdn`

# Temporary folder on the host for deployment orchestration and fuse mounts
HOST_FOLDER="/tmp/SWAN-in-Docker/"
CVMFS_FOLDER=$HOST_FOLDER"cvmfs_mount"
EOS_FOLDER=$HOST_FOLDER"eos_mount"

# LDAP volume names
LDAP_DB="openldap_database"
LDAP_CF="openldap_config"

# Notebook image(s)
NOTEBOOK_IMAGES=(cernphsft/systemuser:v2.9) # , jupyter/minimal-notebook)


### Variables for EOS
# Version
# NOTE: The base OS for EOS AQUAMARINE is CERN SLC6, while for CITRINE is CERN CC7.
# It is recommended to pin EOS and XROOTD versions to
#        AQUAMARINE: 
#		EOS:    0.3.231
#               XRD:    3.3.6
#        CITRINE:
#               EOS:    
#               XRD:  
unset EOS_VERSION XRD_VERSION

EOS_SUPPORTED_VERSIONS=(AQUAMARINE CITRINE)
EOS_CODENAME="AQUAMARINE"	# Pick one among EOS_SUPPORTED_VERSIONS
#EOS_CODENAME="CITRINE"
EOS_VERSION="0.3.231"		# If left empty, the latests version will be installed
XRD_VERSION="3.3.6"

# Container names
#TODO: These names should be forwarded to the eos deployment script
EOSSTORAGE_HEADING="eos-"
EOSSTORAGE_FST_AMOUNT=6
EOSSTORAGE_MGM="mgm"
EOSSTORAGE_MQ="mq"
EOSSTORAGE_FST_NAME="fst"


# ----- Functions ----- #
# Check to be root
need_root()
{
if [ "$EUID" -ne 0 ]; then
	echo "Please run as root"
	exit 1
else
	echo "I am root."
fi
}

# Check to have certificates for TLS
need_certificates()
{
if [[ -f secrets/boxed.crt && -f secrets/boxed.key ]]; then
	echo "I have certificates for HTTPS."
else
	echo "Need SSL key and certificate in secrets/boxed.{key,crt}"
	exit 1
fi
}

# Check the requirements for JupyterHub
jupyterhub_requirements()
{
if [[ -f jupyterhub.d/adminslist ]]; then
	echo "I have the adminlist for JupyterHub."
else
	echo "Need usernames for admins, one per line, in jupyterhub.d/adminslist"
	exit 1
fi
}

# Check to have a valid EOS codename
check_eos_codename()
{
for ver in ${EOS_SUPPORTED_VERSIONS[*]}; 
do
	if [[ "$ver" == "$EOS_CODENAME" ]];
	then
		return
	fi
done
echo "Unknown EOS codename. Cannot continue."
exit 1
}

# Print a warning about the required software on the host
warn_about_software_requirements()
{
echo ""
echo "The following software has to be installed:"
echo -e "\t- wget"
echo -e "\t- fuse"
echo -e "\t- git"
echo -e "\t- docker (version 17.03.1-ce or greater)"
echo -e "\t- docker-compose (version 1.11.2 or greater)"
echo ""
echo "Please consider installing it manually or using the script SetupInstall.sh (for CentOS based systems)."
echo ""
}

# Pin the software version and prepend the dash
pin_software_version()
{
if [[ ! -z "$1" ]]; then
        echo "-"$1
else
	echo ""
fi
}


# ----- **CODE** ----- #
# ----- Preliminary Checks ----- # 
echo ""
echo "Preliminary checks..."
need_root
need_certificates
jupyterhub_requirements
check_eos_codename
warn_about_software_requirements

#wait_time=10
#while [ $wait_time -gt 0 ]; do
#   echo -ne "\r$wait_time...\033[0K"
#   sleep 1
#   wait_time=$((wait_time-1))
#done
#echo "Continuing..."


# ----- Preparation and Clean-Up ----- #
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
        echo "Cannot continue. Exiting..."
        echo ""
        exit
        ;;
esac

# Clean up the (eventual) previous deployment
# WARNING: This is not going to work in case a single-user server is still running, e.g., jupyter-userN
#	   Single-user's servers keep CVMFS and EOS locked due to internal mount
echo ""
echo "Cleaning up..."
docker stop jupyterhub openldap openldap-ldapadd cvmfs eos-fuse cernbox cernboxgateway 2>/dev/null
docker rm -f jupyterhub openldap openldap-ldapadd cvmfs eos-fuse cernbox cernboxgateway 2>/dev/null

# NOTE: Containers for EOS storage are not managed by docker-compose
#	They need to be stopped and removed manually
docker stop eos-fst{1..6} eos-mq eos-mgm 2>/dev/null
docker rm -f eos-fst{1..6} eos-mq eos-mgm eos-controller 2>/dev/null

# Remove CMVFS and EOS processes together with related folder for the mount
# TODO: This should be checked (maybe too aggressive?)
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
rm -rf $HOST_FOLDER 2>/dev/null
rmdir $HOST_FOLDER 2>/dev/null
echo "Cleaned."

# Initialize the temporary folder on the host
mkdir -p $HOST_FOLDER
touch "$HOST_FOLDER"DO_NOT_WRITE_ANY_FILE_HERE
echo ""
echo "Continuing with the deployment..."


# ----- Check to have (or pull) the CERN Jupyter notobook server image
# See: https://github.com/cernphsft/systemuser
echo ""
echo "Pulling Single-User-'s notebook image..."
for i in ${NOTEBOOK_IMAGES[*]};
do
        echo "Pulling $i..."
        docker pull $i
done


# ----- EOS storage ---- # 
# Build the Docker image
echo ""
echo "Building the Docker image for EOS storage..."
EOS_VERSION=$(pin_software_version $EOS_VERSION)
XRD_VERSION=$(pin_software_version $XRD_VERSION)
export EOS_DOCKERF=`echo $EOS_CODENAME | tr '[:upper:]' '[:lower:]'`.Dockerfile
docker build -t eos-storage -f eos-storage.d/$EOS_DOCKERF --build-arg EOS_VERSION=${EOS_VERSION} --build-arg XRD_VERSION=${XRD_VERSION} .

# Set up Docker volumes to make storage persistent
echo ""
echo "Initialize Docker volumes for EOS..."
EOS_MGM=$EOSSTORAGE_HEADING$EOSSTORAGE_MGM
EOS_MQ=$EOSSTORAGE_HEADING$EOSSTORAGE_MQ
docker volume inspect $EOS_MQ >/dev/null 2>&1 || docker volume create --name $EOS_MQ
docker volume inspect $EOS_MGM >/dev/null 2>&1 || docker volume create --name $EOS_MGM
for i in {1..6}
do
    EOS_FST=$EOSSTORAGE_HEADING$EOSSTORAGE_FST_NAME$i
    docker volume inspect $EOS_FST >/dev/null 2>&1 || docker volume create --name $EOS_FST
done


# ----- LDAP ----- #
# Set up Docker volumes to persist account information
echo ""
echo "Initialize Docker volume for LDAP..."
docker volume inspect $LDAP_DB >/dev/null 2>&1 || docker volume create --name $LDAP_DB
docker volume inspect $LDAP_CF >/dev/null 2>&1 || docker volume create --name $LDAP_CF

# Set the permissions for LDAP/PAM configuration files
chmod 600 ldappam.d/nslcd.conf


# ----- Network ----- #
# Check to have (or create) a Docker network to allow communications among containers
echo ""
echo "Setting up the Docker network..."
docker network inspect $DOCKER_NETWORK_NAME >/dev/null 2>&1 || docker network create $DOCKER_NETWORK_NAME
docker network inspect $DOCKER_NETWORK_NAME


# ----- Fetch from CERN GitLab ----- #
# Clone the repo with customizations for JupyterHub
echo ""
echo "Fetching CERN customizations for JupyterHub..." 
git clone https://:@gitlab.cern.ch:8443/dmaas/jupyterhub.git jupyterhub.d/jupyterhub-dmaas
git clone https://:@gitlab.cern.ch:8443/ai/it-puppet-hostgroup-dmaas.git jupyterhub.d/jupyterhub-puppet


# ----- Set the locks for controlling the dependencies and execution order ----- #
echo ""
echo "Setting up locks..."
echo "Locking EOS-Storage -- Needs LDAP"
touch /tmp/SWAN-in-Docker/eos-storage-lock
echo "Locking eos-fuse client -- Needs EOS storage"
touch /tmp/SWAN-in-Docker/eos-fuse-lock
echo "Locking cernbox -- Needs EOS storage"
touch /tmp/SWAN-in-Docker/cernbox-lock
echo "Locking cernboxgateway -- Needs EOS storage"
touch /tmp/SWAN-in-Docker/cernboxgateway-lock


# ----- Build and run via Docker Compose ----- #
echo ""
echo "Build and run"
docker-compose build
docker-compose up -d

echo "Access to log files: docker-compose logs -f"

echo "[Done]"




### OLD -- DEPRECATED DEPLOYMENT OF EOS STORAGE ###

# NOT WORKING AS WE NEED LDAP TO RETRIEVE ADMIN INFO BUT LDAP IS NOT READY YES AT THIS STAGE
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

