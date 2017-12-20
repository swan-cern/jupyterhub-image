#! /bin/bash

# This script automatically fetches CERN customizations for JupyterHub, which come
# from private repositories on CERN GitLab. Please, check to have the required
# authroizations to clone the repos and to own a valid kerberos ticket before
# running this script.
#
# Customization files are bundled in compressed archives and stored on the local
# machine. Such archives will be used by the building process of the JupyterHub 
# Docker image. Please, consider to add the latest version of the archives to
# the Boxed repo so to keep it consistent with the content of the Docker image.

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TMP_FOLDER="./tmp"
OUT_FOLDER="./jupyterhub_CERN"

# Clone the repo
mkdir -p $TMP_FOLDER
git clone https://:@gitlab.cern.ch:8443/ai/it-puppet-hostgroup-dmaas.git $TMP_FOLDER"/manifest"
git clone https://:@gitlab.cern.ch:8443/dmaas/jupyterhub.git $TMP_FOLDER"/jupyterhub"

# Prepare the files to build the Docker images
mkdir -p $OUT_FOLDER
tar -cz -f $OUT_FOLDER"/CERNHandlers.tar.gz" $TMP_FOLDER"/jupyterhub/CERNHandlers"
tar -cz -f $OUT_FOLDER"/CERNSpawner.tar.gz" $TMP_FOLDER"/jupyterhub/CERNSpawner" 
tar -cz -f $OUT_FOLDER"/CERNTemplates.tar.gz" $TMP_FOLDER"/jupyterhub/templates"           
tar -cz -f $OUT_FOLDER"/CERNLogos.tar.gz" $TMP_FOLDER"/jupyterhub/logo"                    
cp $TMP_FOLDER"/manifest/code/templates/jupyterhub/jupyterhub_form.html.erb" $OUT_FOLDER"/jupyterhub_form.html.erb"
cp $TMP_FOLDER"/jupyterhub/scripts/start_jupyterhub.py" $OUT_FOLDER"/start_jupyterhub.py"

# Clean-up temporary files
rm -rf $TMP_FOLDER

# Done
echo "Done."

