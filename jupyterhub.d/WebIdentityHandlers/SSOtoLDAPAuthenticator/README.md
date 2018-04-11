## JupyterHub SSO to LDAP Authenticator

Authenticate to JupyterHub with a unique (alphanumerical) Web Identity that is internally mapped to a dedicated Unix account.

*NOTE: This authenticator leverages on already-existing mappings and does not have the ability to create new ones.*

For additional information on the mapping, please refer to [UserBackendSSOtoLDAP for CERNBox](https://gitlab.cern.ch/cernbox/boxed/blob/master/cernbox.d/WebIdentityHandlers/README.md#userbackendssotoldap).


#### Installation

This package can be installed with `pip` and `python3`:

    pip3 install -r requirements.txt && \
        python3 setup.py install



#### Configuration

You should edit your file `jupyterhub_config.py` to set the authenticator class:

    c.JupyterHub.authenticator_class = 'ssotoldap_authenticator.ssotoldap_user_auth.SSOUserAuthenticator

