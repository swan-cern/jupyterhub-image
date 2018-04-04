###
# Remember to authorize the pod where JupyterHub runs to access the API 
# of the cluster and to list pods in the namespace
#
# As temporary workaround:
# kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=boxed:default
###

# Configuration file for JupyterHub
import os
import socket


### VARIABLES ###
# Get configuration parameters from environment variables
CVMFS_FOLDER            = os.environ['CVMFS_FOLDER']
EOS_FOLDER              = os.environ['EOS_FOLDER']
CONTAINER_IMAGE         = os.environ['CONTAINER_IMAGE']
LDAP_ENDPOINT           = os.environ['LDAP_ENDPOINT']
NAMESPACE               = os.environ['PODINFO_NAMESPACE']
NODE_SELECTOR_KEY       = os.environ['NODE_SELECTOR_KEY']
NODE_SELECTOR_VALUE     = os.environ['NODE_SELECTOR_VALUE']


c = get_config()

### Configuration for JupyterHub ###
# JupyterHub runtime configuration
jupyterhub_runtime_dir = '/srv/jupyterhub/jupyterhub_data/'
os.makedirs(jupyterhub_runtime_dir, exist_ok=True)
c.JupyterHub.cookie_secret_file = os.path.join(jupyterhub_runtime_dir, 'cookie_secret')
c.JupyterHub.db_url = os.path.join(jupyterhub_runtime_dir, 'jupyterhub.sqlite')

# Resume previous state if the Hub fails
c.JupyterHub.proxy_auth_token = '122aee66284d48c032752e16d650ae6b71181c96cec3798fa9b335d17111511a'
c.JupyterHub.cleanup_proxy = False
c.JupyterHub.cleanup_servers = False	# Note: Need to store the sqlite database on persistent storage

# Logging
c.JupyterHub.extra_log_file = '/var/log/jupyterhub.log'
c.JupyterHub.log_level = 'DEBUG'
c.Spawner.debug = True
c.LocalProcessSpawner.debug = True

# Add SWAN look&feel
c.JupyterHub.template_paths = ['/srv/jupyterhub/templates']
c.JupyterHub.logo_file = '/srv/jupyterhub/logo/logo_swan_cloudhisto.png'

# TLS configuration to reach the Hub from the outside
c.JupyterHub.ip = "0.0.0.0"     # Listen on all IPs for HTTP traffic when in Kubernetes
c.JupyterHub.port = 8000	# You may end up in detecting the wrong IP address due to:
	                        #       - Kubernetes services in front of Pods (headed//headless//clusterIPs)
	                        #       - hostNetwork used by the JupyterHub Pod

# Configuration to reach the Hub from Jupyter containers
# NOTE: The Hub IP must be known and rechable from spawned containers
# 	Leveraging on the FQDN makes the Hub accessible both when the JupyterHub Pod 
#	uses the Kubernetes overlay network and the host network
try:
  hub_ip = socket.gethostbyname(socket.getfqdn())
except:
  print ("WARNING: Unable to identify iface IP from FQDN")
  s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
  s.connect(("8.8.8.8", 80))
  hub_ip = s.getsockname()[0]
hub_port = 8080
c.JupyterHub.hub_ip = hub_ip
c.JupyterHub.hub_port = hub_port
c.KubeSpawner.hub_connect_ip = hub_ip
c.KubeSpawner.hub_connect_port = hub_port

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

# Spawn single-user's servers in the Kubernetes cluster
c.JupyterHub.spawner_class = 'cernkubespawner.CERNKubeSpawner'
c.CERNKubeSpawner.singleuser_image_spec = CONTAINER_IMAGE
c.CERNKubeSpawner.namespace = NAMESPACE                                                 # Namespace of the whole machines (unless you want to separete SWAN users for accounting reasons)
c.CERNKubeSpawner.singleuser_node_selector = {NODE_SELECTOR_KEY : NODE_SELECTOR_VALUE}  # Where to run user containers
c.CERNKubeSpawner.options_form = '/srv/jupyterhub/jupyterhub_form.html'
c.CERNKubeSpawner.start_timeout = 60 * 5    # Can be very high if the user image is not available locally yet
                                            # TODO: Need to pre-fetch the image somehow

# Single-user's servers extra config, CVMFS, EOS
#c.CERNKubeSpawner.extra_host_config = { 'mem_limit': '8g', 'cap_drop': ['NET_BIND_SERVICE', 'SYS_CHROOT']}

#c.CERNKubeSpawner.local_home = True	# $HOME is a volatile scratch space at /scratch/<username>/
c.CERNKubeSpawner.local_home = False	# $HOME is on EOS
c.CERNKubeSpawner.volume_mounts = [
    {
        'name': 'cvmfs',
        'mountPath': '/cvmfs:shared',
    },
    {
        'name': 'eos',
        'mountPath': '/eos/user:shared',
    }
]

c.CERNKubeSpawner.volumes = [
    {
        'name': 'cvmfs',
        'hostPath': {
            'path': '/cvmfs',
            'type': 'Directory',
        }
    },
    {
        'name': 'eos',
        'hostPath': {
            'path': '/eos/docker/user',
            'type': 'Directory',
        }
    }
]

