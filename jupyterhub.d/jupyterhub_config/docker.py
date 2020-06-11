# Configuration file for JupyterHub

import os


### VARIABLES ###
# Get configuration parameters from environment variables
DOCKER_NETWORK_NAME     = os.environ['DOCKER_NETWORK_NAME']
CVMFS_FOLDER            = os.environ['CVMFS_FOLDER']
EOS_FOLDER              = os.environ['EOS_FOLDER']
CONTAINER_IMAGE         = os.environ['CONTAINER_IMAGE']
LDAP_URI                = os.environ['LDAP_URI']
LDAP_PORT               = os.environ['LDAP_PORT']
LDAP_BASE_DN            = os.environ['LDAP_BASE_DN']

c = get_config()

### Configuration for JupyterHub ###
# JupyterHub
c.JupyterHub.cookie_secret_file = '/srv/jupyterhub/cookie_secret'
c.JupyterHub.db_url = '/srv/jupyterhub/jupyterhub.sqlite'

# Logging
c.JupyterHub.log_level = 'DEBUG'
c.Spawner.debug = True
c.LocalProcessSpawner.debug = True

# Add SWAN look&feel
c.JupyterHub.template_paths = ['/srv/jupyterhub/jh_gitlab/templates']
c.JupyterHub.logo_file = '/usr/local/share/jupyterhub/static/swan/logos/logo_swan_cloudhisto.png'

# Reach the Hub from local httpd (proxypass)
c.JupyterHub.ip = "127.0.0.1"
c.JupyterHub.port = 8000

# Reach the Hub from Jupyter containers
c.JupyterHub.hub_ip = "jupyterhub"
c.JupyterHub.hub_port = 8080

c.JupyterHub.cleanup_servers = False
# Use local_home set to true to prevent calling the script that updates EOS tickets
c.JupyterHub.services = [
    {
        'name': 'cull-idle',
        'admin': True,
        'command': 'python3 /srv/jupyterhub/jh_gitlab/scripts/cull_idle_servers.py --cull_every=600 --timeout=14400 --local_home=True --cull_users=True'.split(),
    },
    {
        'name': 'notifications',
        'command': 'python3 -m swannotificationsservice --port 8989'.split(),
        'url': 'http://127.0.0.1:8989'
    }
]

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
# Spawn single-user's servers as Docker containers
c.JupyterHub.spawner_class = 'swanspawner.SwanDockerSpawner'
c.SwanSpawner.image = CONTAINER_IMAGE
c.SwanSpawner.remove_containers = True
c.SwanSpawner.options_form = '/srv/jupyterhub/jupyterhub_form.html'

# Instruct spawned containers to use the internal Docker network
c.SwanSpawner.use_internal_ip = True
c.SwanSpawner.network_name = DOCKER_NETWORK_NAME
c.SwanSpawner.extra_host_config = { 'network_mode': DOCKER_NETWORK_NAME }

# Single-user's servers extra config, CVMFS, EOS
#c.SwanSpawner.extra_host_config = { cap_drop': ['NET_BIND_SERVICE', 'SYS_CHROOT']}
c.SwanSpawner.read_only_volumes = { CVMFS_FOLDER : '/cvmfs' }

# Local home inside users' containers
#c.SwanSpawner.local_home = True		# If set to True, user <username> $HOME will be /scratch/<username>/
c.SwanSpawner.local_home = False
c.SwanSpawner.volumes = { os.path.join(EOS_FOLDER, "docker", "user") : '/eos/user' }
c.SwanSpawner.available_cores = ["2", "4"]
c.SwanSpawner.available_memory = ["8", "10"]
c.SwanSpawner.check_cvmfs_status = False #For now it only checks if available in same place as Jupyterhub.

c.SwanSpawner.extra_env = dict(
    SHARE_CBOX_API_DOMAIN = "https://%%%CERNBOXGATEWAY_HOSTNAME%%%",
    SHARE_CBOX_API_BASE   = "/cernbox/swanapi/v1",
    HELP_ENDPOINT         = "https://raw.githubusercontent.com/swan-cern/help/up2u/"
)

# local_home equal to true to hide the "always start with this config"
c.SpawnHandlersConfigs.local_home = True
c.SpawnHandlersConfigs.metrics_on = False #For now the metrics are hardcoded for CERN
c.SpawnHandlersConfigs.spawn_error_message = """SWAN could not start a session for your user, please try again. If the problem persists, please check:
<ul>
    <li>Do you have a CERNBox account? If not, click <a href="https://%%%CERNBOXGATEWAY_HOSTNAME%%%" target="_blank">here</a>.</li>
    <li>Check with the service manager that SWAN is running properly.</li>
</ul>"""
