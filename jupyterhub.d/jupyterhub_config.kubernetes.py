# Configuration file for JupyterHub
import os
import socket


### VARIABLES ###
# Network configuration for the Hub (reachability from the outside)
SSL_KEY = "/srv/jupyterhub/secrets/jupyterhub.key"
SSL_CERT = "/srv/jupyterhub/secrets/jupyterhub.crt"

# Get configuration parameters from environment variables
SINGLEUSER_IMAGE_NAME	= os.environ['SINGLEUSER_IMAGE_NAME']
DOCKER_NETWORK_NAME	= os.environ['DOCKER_NETWORK_NAME']
CVMFS_FOLDER		= os.environ['CVMFS_FOLDER']
EOS_FOLDER		= os.environ['EOS_FOLDER']


c = get_config()

### Configuration for JupyterHub ###
# JupyterHub
c.JupyterHub.cookie_secret_file = '/srv/jupyterhub/cookie_secret'
c.JupyterHub.db_url = '/srv/jupyterhub/jupyterhub.sqlite'
c.JupyterHub.extra_log_file = '/var/log/jupyterhub.log'

# Add SWAN look&feel
c.JupyterHub.template_paths = ['/jupyterhub-dmaas/templates']
c.JupyterHub.logo_file = '/jupyterhub-dmaas/logo/logo_swan_cloudhisto.png'

# Load the list of users with admin privileges and enable access
admins = set(open(os.path.join(os.path.dirname(__file__), 'adminslist'), 'r').read().splitlines())
c.Authenticator.admin_users = admins
c.JupyterHub.admin_access = True


### Network configuration ###
public_ip = socket.gethostbyname(socket.getfqdn())

# TLS configuration to reach the Hub from the outside --> You need a Kubernetes service to make it reachable.
c.JupyterHub.ip = public_ip
c.JupyterHub.port = 443
c.JupyterHub.ssl_key = SSL_KEY
c.JupyterHub.ssl_cert = SSL_CERT

# Configuration to reach the Hub from Jupyter containers
# NOTE: Containers are connected to a separate Docker network: DOCKER_NETWORK_NAME
#	The hub must listen on an IP address that is reachable from DOCKER_NETWORK_NAME
#	and not on "localhost"//"127.0.0.1" or any other name that could not be resolved
#	See also c.CERNSpawner.hub_ip_connect (https://github.com/jupyterhub/jupyterhub/issues/291)
c.JupyterHub.hub_ip = public_ip
c.JupyterHub.hub_port = 8080

# Spawner configuration
c.JupyterHub.spawner_class = 'cernspawner.CERNSpawner'
#c.CERNSpawner.hub_ip_connect = public_ip
c.CERNSpawner.use_internal_ip = True
c.CERNSpawner.network_name = DOCKER_NETWORK_NAME
c.CERNSpawner.extra_host_config = { 'network_mode': DOCKER_NETWORK_NAME }
#c.CERNSpawner.extra_start_kwargs = { 'network_mode': DOCKER_NETWORK_NAME }	# Deprecated since 1.10


### User Authentication ###
# See: https://github.com/jupyterhub/ldapauthenticator
c.JupyterHub.authenticator_class = 'ldapauthenticator.LDAPAuthenticator'

# LDAP for dockerized server 
# https://github.com/jupyterhub/ldapauthenticator, https://github.com/osixia/docker-openldap
c.LDAPAuthenticator.server_address = 'ldap'
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
# CERN SSO
c.JupyterHub.authenticator_class = 'ssoauthenticator.SSOAuthenticator'
#
# Possibly uncomment this
#c.SSOAuthenticator.accepted_egroup = 'swan-admins;swan-qa;swan-qa2'
'''


### Configuration for single-user containers ###

# Spawn single-user's servers as Docker containers
c.CERNSpawner.container_image = SINGLEUSER_IMAGE_NAME
c.CERNSpawner.remove_containers = True
c.CERNSpawner.options_form = '/srv/jupyterhub/jupyterhub_form.html'

# Single-user's servers extra config, CVMFS, EOS
#c.CERNSpawner.extra_host_config = { 'mem_limit': '8g', 'cap_drop': ['NET_BIND_SERVICE', 'SYS_CHROOT']}
c.CERNSpawner.read_only_volumes = { CVMFS_FOLDER : '/cvmfs' }

# Local home inside users' containers
#c.CERNSpawner.local_home = True		# If set to True, user <username> $HOME will be /scratch/<username>/
# TODO: This is a workaround to facilitate debugging while we configure EOS
#	Mapping: /tmp/SWAN-in-Docker/eos_mount/demo/user to /eos/user on single-user Jupyter container
#	EOS_FOLDER should include /demo/user to hide the proc directory to users 

### Revert when EOS is ready
c.CERNSpawner.local_home = False
c.CERNSpawner.volumes = { os.path.join(EOS_FOLDER, "docker", "user") : '/eos/user' }
###c.CERNSpawner.local_home = True
###c.CERNSpawner.volumes = { EOS_FOLDER : '/eos' }

