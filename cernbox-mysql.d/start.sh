#!/bin/bash
#set -o errexit # Bail out on all errors immediately


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

    # Set permission and owner on MySQL data folder (as it should be saved on persistent volumes)
    # Note: The directory will already exist (as mounted with persistent volumes)
    #       Check if it is empty and, if so, set attributes
    DATA_PATH="/var/lib/mysql"
    if [ ! "$(ls -A $DATA_PATH)" ]; then
      echo "Configuring directory for MySQL database..."
      chown -R mysql:mysql $DATA_PATH
      chmod -R 640 $DATA_PATH
      # If there is a backup (e.g., to preserve pre-populated DB), put it back in place
      if [ -d "/tmp/var-lib-mysql" ]; then
        cp -p -r /tmp/var-lib-backend/. $DATA_PATH
      fi
    fi
    ;;

  "compose")
    # Not used in the docker-compose context
    ;;

    *)
    echo "ERROR: Deployment context is not defined."
    echo "Cannot continue."
    exit -1
esac

# Give the control back to the built-in script
./docker-entrypoint.sh mysqld
