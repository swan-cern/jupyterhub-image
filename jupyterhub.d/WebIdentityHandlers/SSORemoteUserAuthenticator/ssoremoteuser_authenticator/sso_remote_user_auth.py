# Author: Enrico Bocchi, 2018
# Inspired from https://github.com/cwaldbieser/jhub_remote_user_authenticator/blob/master/jhub_remote_user_authenticator/remote_user_auth.py


import os
from jupyterhub.handlers import BaseHandler
from jupyterhub.auth import Authenticator
from jupyterhub.auth import LocalAuthenticator
from jupyterhub.utils import url_path_join
from tornado import gen, web
from traitlets import Unicode



class RemoteUserLogoutHandler(BaseHandler):
    """
    Log a user out by clearing her JupyterHub login cookie.
    Clearing out SSO cookie is deferred to a hook on the SSO side callable
    from a URL, which can be set via the 'SSO_LOGOUT_URL' parameter.
    """
    def get(self):
        if ('SSO_LOGOUT_URL' not in os.environ.keys()):
            sso_logout_url = "https://swan.web.cern.ch"
        else:
            sso_logout_url = os.environ['SSO_LOGOUT_URL']

        user = self.get_current_user()
        self.clear_login_cookie()
        if user:
            self.log.info("INFO: User logged out: %s", user.name)
            for name in user.other_user_cookies:
                self.clear_login_cookie(name)
            user.other_user_cookies = set([])
        self.redirect(sso_logout_url, permanent=False)



class RemoteUserLoginHandler(BaseHandler):
    """Log a user in and user the SSO-provided uid to spawn the session."""
    def get(self):
        header_name = self.authenticator.header_name
        sso_uid = self.request.headers.get(header_name, "")

        # If the field is empty, I cannot authenticate the user
        if (sso_uid == ""):
            self.log.info("ERROR: SSO_UID field from Shibboleth is empty")
            raise web.HTTPError(401)
            return

        # Otherwise, use the SSO-provided uid
        user = self.user_from_username(sso_uid)
        self.log.info("INFO: User logged in: %s", user.name)
        self.set_login_cookie(user)
        self.redirect(url_path_join(self.hub.server.base_url, 'home'))



class RemoteUserAuthenticator(Authenticator):
    """
    Accept the SSO-provided unique identifier (SSO_UID) from the REMOTE_USER HTTP header.
    """
    header_name = Unicode(
        default_value='REMOTE_USER',
        config=True,
        help="""HTTP header to inspect for the authenticated username.""")

    def get_handlers(self, app):
        return [
            (r'/sso_login', RemoteUserLoginHandler),
            (r'/sso_logout', RemoteUserLogoutHandler),
        ]

    @gen.coroutine
    def authenticate(self, *args):
        raise NotImplementedError()



class RemoteUserLocalAuthenticator(LocalAuthenticator):
    """
    Accept the SSO-provided unique identifier (SSO_UID) from the REMOTE_USER HTTP header.
    Derived from LocalAuthenticator for use of features such as adding
    local accounts through the admin interface.
    """
    header_name = Unicode(
        default_value='REMOTE_USER',
        config=True,
        help="""HTTP header to inspect for the authenticated username.""")

    def get_handlers(self, app):
        return [
            (r'/sso_login', RemoteUserLoginHandler),
            (r'/sso_logout', RemoteUserLogoutHandler),
        ]

    @gen.coroutine
    def authenticate(self, *args):
        raise NotImplementedError()
