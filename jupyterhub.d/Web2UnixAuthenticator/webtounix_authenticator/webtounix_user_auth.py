# Author: Enrico Bocchi, 2018

"""Web to Unix Authenticator"""

# Inspired from https://github.com/cwaldbieser/jhub_remote_user_authenticator/blob/master/jhub_remote_user_authenticator/remote_user_auth.py


import os
from jupyterhub.handlers import BaseHandler
from jupyterhub.auth import Authenticator
from jupyterhub.auth import LocalAuthenticator
from jupyterhub.utils import url_path_join
from tornado import gen, web
from traitlets import Unicode
from ldap3 import Server, Connection, ALL



class SSOUserLogoutHandler(BaseHandler):
    """Log a user out by clearing both their JupyterHub login cookie and SSO cookie."""
    def get(self):
        sso_logout_redirect = os.environ['SSO_LOGOUT_REDIRECT']

        user = self.get_current_user()
        self.clear_login_cookie()
        if user:
            self.log.info("User logged out: %s", user.name)
            for name in user.other_user_cookies:
                self.clear_login_cookie(name)
            user.other_user_cookies = set([])
        self.redirect(sso_logout_redirect, permanent=False)



class SSOUserLoginHandler(BaseHandler):
    """Log a user in an lookup for her Unix account on LDAP."""
    def get(self):
        unix_user_attrname	= "uid"
        sso_uid_attrname	= "ssouid"
        object_class            = "ssoUnixMatch"
        ldap_endpoint		= os.environ['LDAP_ENDPOINT']
        ldap_basedn		= os.environ['LDAP_BASEDN']
        ldap_binddn		= os.environ['LDAP_BINDDN']
        ldap_binddn_pwd		= os.environ['LDAP_BINDDN_PWD']

        header_name = self.authenticator.header_name
        sso_uid = self.request.headers.get(header_name, "")

        # If the field is empty, I cannot authenticate the user
        if (sso_uid == ""):
            print ("ERROR: SSO_UID field from Shibboleth is empty")
            raise web.HTTPError(401)
            return
	
        # SSO to Unix mapping via LDAP entry
        """
        NOTE: It is given for granted that the user is already known to LDAP
        thanks to a previous login to CERNBox. If that is not the case, the 
        user will be shown a page redirecting to CERNBox login.
        """
        # Retrieve entries from LDAP server
        search_filter = "(&(objectclass=%s)(%s=%s))" %(object_class, sso_uid_attrname, sso_uid)
        wanted_attributes = [unix_user_attrname]
        try:
            ldap_srv = Server(ldap_endpoint, get_info=ALL)
            ldap_conn = Connection(ldap_srv, ldap_binddn, ldap_binddn_pwd, auto_bind=True)
            ldap_conn.search(ldap_basedn, search_filter, attributes=wanted_attributes)
            ldap_result = ldap_conn.entries
        except Exception as e:
            print ("ERROR: Unable to retrieve entries from LDAP Server.")
            print (e)
            raise web.HTTPError(503)
            return

        # Handle the response
        if (len(ldap_result) == 0):
            print ("ERROR: Matching entry for SSO_UID %s not found" %(sso_uid))
            raise web.HTTPError(403)
            return
        if (len(ldap_result) > 1):
            print ("ERROR: More than one matching entry found for SSO_UID %s" %(sso_uid))
            raise web.HTTPError(401)
            return
        try:
            unix_user = getattr(ldap_result[0], unix_user_attrname).value
        except:
            print ("ERROR: Something went wrong parsing the LDAP response for SSO_UID %s" %(sso_uid))
            raise web.HTTPError(401)
            return

        # From now on, use the Unix uid instead of the SSO one
        user = self.user_from_username(unix_user)
        self.set_login_cookie(user)
        self.redirect(url_path_join(self.hub.server.base_url, 'home'))



class SSOUserAuthenticator(Authenticator):
    """
    Accept the SSO-provided unique identifier (SSO_UID) from the REMOTE_USER HTTP header.
    """
    header_name = Unicode(
        default_value='REMOTE_USER',
        config=True,
        help="""HTTP header to inspect for the authenticated user id.""")

    def get_handlers(self, app):
        return [
            (r'/sso_login', SSOUserLoginHandler),
            (r'/sso_logout', SSOUserLogoutHandler),
        ]

    @gen.coroutine
    def authenticate(self, *args):
        raise NotImplementedError()



class SSOUserLocalAuthenticator(LocalAuthenticator):
    """
    Accept the SSO-provided unique identifier (SSO_UID) from the REMOTE_USER HTTP header.
    Derived from LocalAuthenticator for use of features such as adding
    local accounts through the admin interface.
    """
    header_name = Unicode(
        default_value='REMOTE_USER',
        config=True,
        help="""HTTP header to inspect for the authenticated user id.""")

    def get_handlers(self, app):
        return [
            (r'/sso_login', SSOUserLoginHandler),
            (r'/sso_logout', SSOUserLogoutHandler),
        ]

    @gen.coroutine
    def authenticate(self, *args):
        raise NotImplementedError()

