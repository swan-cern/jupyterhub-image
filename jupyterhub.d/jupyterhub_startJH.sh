#!/bin/bash 

# Eventually override the certificates with the ones available in certs/boxed.{key,crt}
if [[ -f "$HOST_FOLDER"/certs/boxed.crt && -f "$HOST_FOLDER"/certs/boxed.key ]]; then
        echo 'Replacing default certificate for HTTPS'
        /bin/cp "$HOST_FOLDER"/certs/boxed.crt /srv/jupyterhub/secrets/jupyterhub.crt
        /bin/cp "$HOST_FOLDER"/certs/boxed.key /srv/jupyterhub/secrets/jupyterhub.key
fi

# Start nscd and nslcd to get user information from LDAP
nscd
nslcd

# Start JupyterHub
python3 /jupyterhub-dmaas/scripts/start_jupyterhub.py --config /srv/jupyterhub/jupyterhub_config.py

