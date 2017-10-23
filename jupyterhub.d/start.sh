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

    sed -i "s/%%%LDAP_ENDPOINT%%%/${LDAP_ENDPOINT}/" /etc/nslcd.conf
    nscd
    nslcd

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
      /bin/cp "$HOST_FOLDER"/certs/boxed.crt /srv/jupyterhub/secrets/jupyterhub.crt
      /bin/cp "$HOST_FOLDER"/certs/boxed.key /srv/jupyterhub/secrets/jupyterhub.key
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

# Start JupyterHub
echo "Starting JupyterHub..."
python3 /jupyterhub-dmaas/scripts/start_jupyterhub.py --config /srv/jupyterhub/jupyterhub_config.py

