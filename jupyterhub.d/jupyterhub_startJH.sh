#!/bin/bash 

# Start nscd and nslcd to get user information from LDAP
nscd
nslcd

# Start JupyterHub
python3 /jupyterhub-dmaas/scripts/start_jupyterhub.py --config /srv/jupyterhub/jupyterhub_config.py

