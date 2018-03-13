# Configuration file for JupyterHub
import os
import socket


### VARIABLES ###
# Get configuration parameters from environment variables
DOCKER_NETWORK_NAME     = os.environ['DOCKER_NETWORK_NAME']
CVMFS_FOLDER            = os.environ['CVMFS_FOLDER']
EOS_FOLDER              = os.environ['EOS_FOLDER']
CONTAINER_IMAGE         = os.environ['CONTAINER_IMAGE']
LDAP_ENDPOINT           = os.environ['LDAP_ENDPOINT']

c = get_config()

### Configuration for JupyterHub ###
# JupyterHub
c.JupyterHub.cookie_secret_file = '/srv/jupyterhub/cookie_secret'
c.JupyterHub.db_url = '/srv/jupyterhub/jupyterhub.sqlite'

# Logging
c.JupyterHub.extra_log_file = '/var/log/jupyterhub.log'
c.JupyterHub.log_level = 'DEBUG'
c.Spawner.debug = True
c.LocalProcessSpawner.debug = True

# Add SWAN look&feel
c.JupyterHub.template_paths = ['/srv/jupyterhub/templates']
c.JupyterHub.logo_file = '/srv/jupyterhub/logo/logo_swan_cloudhisto.png'

# TLS configuration to reach the Hub from the outside
c.JupyterHub.ip = "127.0.0.1"
c.JupyterHub.port = 8000

# Configuration to reach the Hub from Jupyter containers
# NOTE: Containers are connected to a separate Docker network: DOCKER_NETWORK_NAME
#       The hub must listen on an IP address that is reachable from DOCKER_NETWORK_NAME
#       and not on "localhost"||"127.0.0.1" or any other name that could not be resolved
#       See also c.CERNSpawner.hub_ip_connect (https://github.com/jupyterhub/jupyterhub/issues/291)
public_ip = socket.gethostbyname(socket.getfqdn())
c.JupyterHub.hub_ip = public_ip
c.JupyterHub.hub_port = 8080

# Load the list of users with admin privileges and enable access
admins = set(open(os.path.join(os.path.dirname(__file__), 'adminslist'), 'r').read().splitlines())
c.Authenticator.admin_users = admins
c.JupyterHub.admin_access = True

### User Authentication ###
if ( os.environ['AUTH_TYPE'] == "cernsso" ):
    print ("Authenticator: Using CERN SSO")
    c.JupyterHub.authenticator_class = 'ssoauthenticator.SSOAuthenticator'
    c.SSOAuthenticator.accepted_egroup = 'swan-admins;swan-qa;swan-qa2'
elif ( os.environ['AUTH_TYPE'] == "shibboleth" ):
    print ("Authenticator: Using user-defined authenticator")
    c.JupyterHub.authenticator_class = '%%%SHIBBOLETH_AUTHENTICATOR_CLASS%%%'
elif ( os.environ['AUTH_TYPE'] == "local" ):
    print ("Authenticator: Using LDAP")
    # See: https://github.com/jupyterhub/ldapauthenticator
    c.JupyterHub.authenticator_class = 'ldapauthenticator.LDAPAuthenticator'

    c.LDAPAuthenticator.server_address = LDAP_ENDPOINT
    c.LDAPAuthenticator.use_ssl = True
    c.LDAPAuthenticator.server_port = 636
    # LDAP tries to authenticate the client, but we are running on self-signed certificates.
    # One could alway add the self-signed certificate to the LDAP side...
    # or make client authentication not mandatory --> in docker-compose.yaml set 'LDAP_TLS_VERIFY_CLIENT: try'
    # Have a look at: https://github.com/osixia/docker-openldap/issues/105
    #   ldap      | 58de1281 conn=1003 fd=16 ACCEPT from IP=172.18.0.2:57734 (IP=0.0.0.0:636)
    #   ldap      | TLS: can't accept: No certificate was found..
    #   ldap      | 58de1281 conn=1003 fd=16 closed (TLS negotiation failure)
    c.LDAPAuthenticator.bind_dn_template = 'uid={username},dc=example,dc=org'
    #c.LDAPAuthenticator.lookup_dn = True
    #c.LDAPAuthenticator.user_search_base = 'ou=People,dc=example,dc=com'
    #c.LDAPAuthenticator.user_attribute = 'uid'
else:
    print ("ERROR: Authentication type not specified.")
    print ("Cannot start JupyterHub.")

'''
# LDAP for CERN
# https://linux.web.cern.ch/linux/docs/account-mgmt.shtml
c.LDAPAuthenticator.server_address = 'cerndc.cern.ch'   # This guy provides authentication capabilities
#c.LDAPAuthenticator.server_address = 'xldap.cern.ch'   # This doesn't, it is only to access user account information
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

### Configuration for single-user containers ###

# Spawn single-user's servers as Docker containers
c.JupyterHub.spawner_class = 'cernspawner.CERNSpawner'
c.CERNSpawner.image = CONTAINER_IMAGE
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
c.CERNSpawner.local_home = False
c.CERNSpawner.volumes = { os.path.join(EOS_FOLDER, "docker", "user") : '/eos/user' }

