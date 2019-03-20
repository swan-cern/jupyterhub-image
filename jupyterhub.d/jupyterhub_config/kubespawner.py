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
EOS_USER_PATH           = os.environ['EOS_USER_PATH']
CONTAINER_IMAGE         = os.environ['CONTAINER_IMAGE']
LDAP_URI                = os.environ['LDAP_URI']
LDAP_PORT               = os.environ['LDAP_PORT']
LDAP_BASE_DN            = os.environ['LDAP_BASE_DN']
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
c.JupyterHub.cleanup_proxy = False      # Do not kill the proxy if the hub fails (will return 'Service Unavailable')
c.JupyterHub.cleanup_servers = False    # Do not kill single-user's servers (SQLite DB must be on persistent storage)

# Logging
c.JupyterHub.log_level = 'DEBUG'
c.Spawner.debug = True
c.LocalProcessSpawner.debug = True

# Add SWAN look&feel
c.JupyterHub.template_paths = ['/srv/jupyterhub/jh_gitlab/templates']
c.JupyterHub.logo_file = '/usr/local/share/jupyterhub/static/swan/logos/logo_swan_cloudhisto.png'

# Reach the Hub from outside
c.JupyterHub.ip = "0.0.0.0"     # Listen on all IPs for HTTP traffic when in Kubernetes
c.JupyterHub.port = 8000	# You may end up in detecting the wrong IP address due to:
	                        #       - Kubernetes services in front of Pods (headed//headless//clusterIPs)
	                        #       - hostNetwork used by the JupyterHub Pod

# Reach the Hub from Jupyter containers
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

# Proxy
# Wrap the start of the proxy to allow bigger headers in nodejs
c.ConfigurableHTTPProxy.command = '/srv/jupyterhub/jh_gitlab/scripts/start_proxy.sh'

# Load the list of users with admin privileges and enable access
admins = set(open(os.path.join(os.path.dirname(__file__), 'adminslist'), 'r').read().splitlines())
c.Authenticator.admin_users = admins
c.JupyterHub.admin_access = True

### User Authentication ###
if ( os.environ['AUTH_TYPE'] == "shibboleth" ):
    print ("Authenticator: Using user-defined authenticator")
    c.JupyterHub.authenticator_class = '%%%SHIBBOLETH_AUTHENTICATOR_CLASS%%%'
    # %%% Additional SHIBBOLETH_AUTHENTICATOR_CLASS parameters here %%% #

elif ( os.environ['AUTH_TYPE'] == "local" ):
    print ("Authenticator: Using LDAP")
    c.JupyterHub.authenticator_class = 'ldapauthenticator.LDAPAuthenticator'
    c.LDAPAuthenticator.server_address = LDAP_URI
    c.LDAPAuthenticator.use_ssl = False
    c.LDAPAuthenticator.server_port = int(LDAP_PORT)
    if (LDAP_URI[0:8] == "ldaps://"):
      c.LDAPAuthenticator.use_ssl = True
    c.LDAPAuthenticator.bind_dn_template = 'uid={username},'+LDAP_BASE_DN

else:
    print ("ERROR: Authentication type not specified.")
    print ("Cannot start JupyterHub.")


### Configuration for single-user containers ###

# Spawn single-user's servers in the Kubernetes cluster
c.JupyterHub.spawner_class = 'cernkubespawner.CERNKubeSpawner'
c.CERNKubeSpawner.image = CONTAINER_IMAGE
c.CERNKubeSpawner.namespace = NAMESPACE
c.CERNKubeSpawner.node_selector = {NODE_SELECTOR_KEY : NODE_SELECTOR_VALUE}  # Where to run user containers
c.CERNKubeSpawner.options_form = '/srv/jupyterhub/jupyterhub_form.html'
c.CERNKubeSpawner.start_timeout = 30

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
            'path': EOS_USER_PATH,
            'type': 'Directory',
        }
    }
]

c.CERNKubeSpawner.extra_env = dict(
    SHARE_CBOX_API_DOMAIN = "https://%%%CERNBOXGATEWAY_HOSTNAME%%%",
    SHARE_CBOX_API_BASE   = "/cernbox/swanapi/v1",
    HELP_ENDPOINT         = "https://raw.githubusercontent.com/swan-cern/help/up2u/"
)

