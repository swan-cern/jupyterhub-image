#!/bin/bash 
#set -o errexit	# Bail out on all errors immediately

echo "---${THIS_CONTAINER}---"

case $DEPLOYMENT_TYPE in
  "kubernetes")
    # Print PodInfo
    echo ""
    echo "%%%--- PodInfo ---%%%"
    echo "Pod namespace: ${PODINFO_NAMESPACE}"
    echo "Pod name: ${PODINFO_NAME}"
    echo "Pod IP: ${PODINFO_IP}"
    echo "Node name (of the host where the pod is running): ${PODINFO_NODE_NAME}" 
    echo "Node IP (of the host where the pod is running): ${PODINFO_NODE_IP}"

    echo "Deploying with configuration for Kubernetes..."
    cp /srv/jupyterhub/jupyterhub_config.kubernetes.py /srv/jupyterhub/jupyterhub_config.py

    echo "Downloading single-user image: $SINGLEUSER_IMAGE_NAME ..."
    docker pull $SINGLEUSER_IMAGE_NAME

    echo "Creating internal Docker network: $DOCKER_NETWORK_NAME ..."
    docker network inspect $DOCKER_NETWORK_NAME > /dev/null 2>&1 || docker network create $DOCKER_NETWORK_NAME
    ;;

  ###
  "kubespawner")
    echo "Deploying with configuration for Kubespawner..."
    cp /srv/jupyterhub/jupyterhub_config.kubespawner.py /srv/jupyterhub/jupyterhub_config.py

    sleep infinity
    ##TODO
    ##python3 /jupyterhub-dmaas/scripts/start_jupyterhub.py --config /srv/jupyterhub/jupyterhub_config.py
    ;;

  ###
  "compose")
    echo "Deploying with configuration for Docker Compose..."

    # Eventually override the certificates with the ones available in certs/boxed.{key,crt}
    if [[ -f "$HOST_FOLDER"/certs/boxed.crt && -f "$HOST_FOLDER"/certs/boxed.key ]]; then
      echo 'Replacing default certificate for HTTPS...'
      /bin/cp "$HOST_FOLDER"/certs/boxed.crt /etc/boxed/certs/boxed.crt
      /bin/cp "$HOST_FOLDER"/certs/boxed.key /etc/boxed/certs/boxed.key
    fi

    cp /srv/jupyterhub/jupyterhub_config.docker.py /srv/jupyterhub/jupyterhub_config.py
    ;;
  *)
    echo "ERROR: Deployment context is not defined."
    echo "Cannot continue."
    exit -1
esac

# Start nscd and nslcd to get user information from LDAP
echo "Starting LDAP services..."
sed -i "s/%%%LDAP_ENDPOINT%%%/${LDAP_ENDPOINT}/" /etc/nslcd.conf
nscd
nslcd

# Configure httpd proxy with correct ports and hostname
echo "CONFIG: HTTP port is ${HTTP_PORT}"
echo "CONFIG: HTTPS port is ${HTTPS_PORT}"
echo "CONFIG: Hostname is ${HOSTNAME}"
sed "s/%%%HTTPS_PORT%%%/${HTTPS_PORT}/" /root/httpd_config/jupyterhub_ssl.conf.template > /etc/httpd/conf.d/jupyterhub_ssl.conf
sed -e "s/%%%HTTP_PORT%%%/${HTTP_PORT}/
s/%%%HTTPS_PORT%%%/${HTTPS_PORT}/
s/%%%HOSTNAME%%%/${HOSTNAME}/" /root/httpd_config/jupyterhub_plain.conf.template > /etc/httpd/conf.d/jupyterhub_plain.conf

# Configure according to selected authentication method
if [ -z "$AUTH_TYPE" ]; then
  echo "WARNING: Authentication type not specified. Defaulting to local LDAP."
  export AUTH_TYPE="local"
fi

case $AUTH_TYPE in
  "local")
    echo "CONFIG: User authentication via LDAP"
    ;;

  "shibboleth")
    echo "CONFIG: User authentication via Shibboleth"
    mv /etc/httpd/conf.d/shib.noload /etc/httpd/conf.d/shib.conf
    cp /root/httpd_config/shib_auth.conf /etc/httpd/conf.d/shib_auth.conf
    shibd
    ;;
esac

echo "Starting JupyterHub..."
httpd
python3 /jupyterhub-dmaas/scripts/start_jupyterhub.py --no-ssl --config /srv/jupyterhub/jupyterhub_config.py

