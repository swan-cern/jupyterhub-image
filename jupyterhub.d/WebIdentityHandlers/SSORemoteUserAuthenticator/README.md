## JupyterHub SSO Remote User Authenticator

Authenticate to JupyterHub using an authenticating proxy that can set the REMOTE_USER header.

Derived from [Jupyterhub REMOTE_USER Authenticator](https://github.com/cwaldbieser/jhub_remote_user_authenticator) for custom needs and ability to reuse Docker specific configurations of httpd and shibd with different authenticators.


The SSO Remote User Authenticator is typically used together with [UserBackendSSOtoLDAPNumericUID for CERNBox](https://gitlab.cern.ch/cernbox/boxed/blob/master/cernbox.d/WebIdentityHandlers/README.md#userbackendssotoldapnumericuid). This is due to the fact that the authenticated user must have a Unix account and the information related to such account must be retrievable from a centralized LDAP server. The authenticator does not have the ability to create accounts in the LDAP server, while the UserBackendSSOtoLDAPNumericUID backend for CERNBox does.


#### Installation

This package can be installed with `pip` and `python3`:

    pip3 install -r requirements.txt && \
        python3 setup.py install



#### Configuration

You should edit your file `jupyterhub_config.py` to set the authenticator class:

    c.JupyterHub.authenticator_class = 'ssoremoteuser_authenticator.sso_remote_user_auth.RemoteUserAuthenticator'

