# Configuration file for JupyterHub

import os


### VARIABLES ###
# Likely duplicated from other configuration files... 
# TODO: this should be improved

# Network configuration for the Hub (reachability from the outside)
SSL_KEY = "/srv/jupyterhub/secrets/jupyterhub.key"
SSL_CERT = "/srv/jupyterhub/secrets/jupyterhub.crt"

# Authenticate users with GitHub OAuth
#OAUTH_CALLBACK_URL = 'https://127.0.0.1/hub/oauth_callback'
#GITHUB_CLIENT_ID = 'e54ff548df72f4ec2987'
#GITHUB_CLIENT_SECRET = 'd7d89029c856c410f29f5c629c3b36514e6c00d1'

# User's Notebook image
#DOCKER_NOTEBOOK_IMAGE = 'jupyter/scipy-notebook'
#DOCKER_NOTEBOOK_IMAGE = 'jupyter/minimal-notebook'
#DOCKER_NOTEBOOK_IMAGE = 'cernphsft/systemuser'
#DOCKER_SPAWN_CMD = 'start-singleuser.sh'
#DOCKER_NOTEBOOK_DIR = '/home/user1'

# Get configuration parameters from environment variables
DOCKER_NETWORK_NAME=os.environ['DOCKER_NETWORK_NAME']
CVMFS_FOLDER=os.environ['CVMFS_FOLDER']
EOS_FOLDER=os.environ['EOS_FOLDER']
CONTAINER_IMAGE=os.environ['CONTAINER_IMAGE']

c = get_config()

### Configuration for JupyterHub ###
# JupyterHub
c.JupyterHub.cookie_secret_file = '/srv/jupyterhub/cookie_secret'
c.JupyterHub.db_url = '/srv/jupyterhub/jupyterhub.sqlite'
c.JupyterHub.extra_log_file = '/var/log/jupyterhub.log'

# Add SWAN look&feel
c.JupyterHub.template_paths = ['/jupyterhub-dmaas/templates']
c.JupyterHub.logo_file = '/jupyterhub-dmaas/logo/logo_swan_cloudhisto.png'

# TLS configuration to reach the Hub from the outside
c.JupyterHub.port = 443
c.JupyterHub.ssl_key = SSL_KEY
c.JupyterHub.ssl_cert = SSL_CERT

# Configuration to reach the Hub from Jupyter containers
c.JupyterHub.hub_ip = "jupyterhub"
c.JupyterHub.hub_port = 8080

# Load the list of users with admin privileges and enable access
admins = set(open(os.path.join(os.path.dirname(__file__), 'adminslist'), 'r').read().splitlines())
c.Authenticator.admin_users = admins
c.JupyterHub.admin_access = True


### User Authentication ###
# See: https://github.com/jupyterhub/ldapauthenticator
c.JupyterHub.authenticator_class = 'ldapauthenticator.LDAPAuthenticator'

# LDAP for dockerized server 
# https://github.com/jupyterhub/ldapauthenticator, https://github.com/osixia/docker-openldap
c.LDAPAuthenticator.server_address = 'openldap'
c.LDAPAuthenticator.use_ssl = True
c.LDAPAuthenticator.server_port = 636
# LDAP tries to authenticate the client, but we are running on self-signed certificates.
# One could alway add the self-signed certificate to the LDAP side...
# or make client authentication not mandatory --> in docker-compose.yaml set 'LDAP_TLS_VERIFY_CLIENT: try'
# Have a look at: https://github.com/osixia/docker-openldap/issues/105
#	openldap      | 58de1281 conn=1003 fd=16 ACCEPT from IP=172.18.0.2:57734 (IP=0.0.0.0:636)
#	openldap      | TLS: can't accept: No certificate was found..
#	openldap      | 58de1281 conn=1003 fd=16 closed (TLS negotiation failure)

c.LDAPAuthenticator.bind_dn_template = 'uid={username},dc=example,dc=org'
#c.LDAPAuthenticator.lookup_dn = True
#c.LDAPAuthenticator.user_search_base = 'ou=People,dc=example,dc=com'
#c.LDAPAuthenticator.user_attribute = 'uid'

'''
# LDAP for CERN
# https://linux.web.cern.ch/linux/docs/account-mgmt.shtml
c.LDAPAuthenticator.server_address = 'cerndc.cern.ch'	# This guy provides authentication capabilities
#c.LDAPAuthenticator.server_address = 'xldap.cern.ch'	# This doesn't, it is only to access user account information
c.LDAPAuthenticator.use_ssl = True
c.LDAPAuthenticator.server_port = 636

c.LDAPAuthenticator.bind_dn_template = 'CN={username},OU=Users,OU=Organic Units,DC=cern,DC=ch'
c.LDAPAuthenticator.lookup_dn = True
c.LDAPAuthenticator.user_search_base = 'OU=Users,OU=Organic Units,DC=cern,DC=ch'
c.LDAPAuthenticator.user_attribute = 'sAMAccountName'

# Optional settings for LDAP
#LDAPAuthenticator.valid_username_regex
#LDAPAuthenticator.allowed_groups
'''

'''
# GitHub OAuth
c.JupyterHub.authenticator_class = 'oauthenticator.GitHubOAuthenticator'
c.GitHubOAuthenticator.oauth_callback_url = OAUTH_CALLBACK_URL
'''

'''
# CERN SSO
c.JupyterHub.authenticator_class = 'ssoauthenticator.SSOAuthenticator'
#
# Possibly uncomment this
#c.SSOAuthenticator.accepted_egroup = 'swan-admins;swan-qa;swan-qa2'
'''


### Configuration for single-user containers ###

# Spawn single-user's servers as Docker containers
c.JupyterHub.spawner_class = 'cernspawner.CERNSpawner'
c.CERNSpawner.container_image = CONTAINER_IMAGE
c.CERNSpawner.remove_containers = True
c.CERNSpawner.options_form = '/srv/jupyterhub/jupyterhub_form.html'

# Instruct spawned containers to use the internal Docker network
c.CERNSpawner.use_internal_ip = True
c.CERNSpawner.network_name = DOCKER_NETWORK_NAME
c.CERNSpawner.extra_host_config = { 'network_mode': DOCKER_NETWORK_NAME }

# Single-user's servers extra config, CVMFS, EOS
#c.CERNSpawner.extra_host_config = { 'mem_limit': '8g', 'cap_drop': ['NET_BIND_SERVICE', 'SYS_CHROOT']}
c.CERNSpawner.read_only_volumes = { CVMFS_FOLDER : '/cvmfs' }

# Local home inside users' containers
#c.CERNSpawner.local_home = True		# If set to True, user <username> $HOME will be /scratch/<username>/
# TODO: This is a workaround to facilitate debugging while we configure EOS
#	Mapping: /tmp/SWAN-in-Docker/eos_mount/demo/user to /eos/user on single-user Jupyter container
#	EOS_FOLDER should include /demo/user to hide the proc directory to users 
c.CERNSpawner.local_home = False
c.CERNSpawner.volumes = { os.path.join(EOS_FOLDER, "docker", "user") : '/eos/user' }
#c.CERNSpawner.volumes = { EOS_FOLDER : '/eos' }


'''
# Default config without CERN customizations
c.JupyterHub.spawner_class = 'dockerspawner.DockerSpawner'

# Explicitly set notebook directory because we'll be mounting a host volume to
# it.  Most jupyter/docker-stacks *-notebook images run the Notebook server as
# user `jovyan`, and set the notebook directory to `/home/jovyan/work`.
# We follow the same convention.
#c.DockerSpawner.notebook_dir = DOCKER_NOTEBOOK_DIR
# Mount the real user's Docker volume on the host to the notebook user's
# notebook directory in the container
#c.DockerSpawner.volumes = { 'jupyterhub-user-{username}': DOCKER_NOTEBOOK_DIR }
#c.DockerSpawner.extra_create_kwargs.update({ 'volume_driver': 'local' })

# For debugging arguments passed to spawned containers
#c.DockerSpawner.debug = True
'''
