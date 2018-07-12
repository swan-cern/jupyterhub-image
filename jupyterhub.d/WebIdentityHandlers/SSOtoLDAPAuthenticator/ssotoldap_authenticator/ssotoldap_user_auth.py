# Author: Enrico Bocchi, 2018
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



class SSOUserLoginHandler(BaseHandler):
    """Log a user in and lookup for her Unix account on LDAP."""
    def get(self):
        unix_user_attrname	= "uid"
        sso_uid_attrname	= "ssouid"
        object_class		= "ssoUnixMatch"
        ldap_uri		= os.environ['LDAP_URI']
        ldap_port		= os.environ['LDAP_PORT']
        ldap_basedn		= os.environ['LDAP_BASE_DN']
        ldap_binddn		= os.environ['LDAP_BIND_DN']
        ldap_binddn_pwd		= os.environ['LDAP_BIND_PASSWORD']

        # Support for whitelisting
        approved_key			= os.environ['APPROVED_KEY'] if ('APPROVED_KEY' in os.environ.keys()) else None
        list_approved_users_path	= os.environ['LIST_APPROVED'] if ('LIST_APPROVED' in os.environ.keys()) else None
        list_approved_users		= None

        header_name = self.authenticator.header_name
        sso_uid = self.request.headers.get(header_name, "")

        # If the field is empty, I cannot authenticate the user
        if (sso_uid == ""):
            self.log.info("ERROR: SSO_UID field from Shibboleth is empty")
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

        # If the proper env vars are set, get ready to check the whitelist
        if approved_key and list_approved_users_path:
            wanted_attributes.append(approved_key)
            try:
                with open(list_approved_users_path, 'r') as file:
                    list_approved_users = file.read().splitlines()
            except IOError:
                self.log.info("ERROR: Whitelist file does not exist at %s", list_approved_users_path)
                raise web.HTTPError(500)
                return

        try:
            ldap_srv = Server(ldap_uri, port=int(ldap_port), get_info=ALL)
            ldap_conn = Connection(ldap_srv, ldap_binddn, ldap_binddn_pwd, auto_bind=True)
            ldap_conn.search(ldap_basedn, search_filter, attributes=wanted_attributes)
            ldap_result = ldap_conn.entries
        except Exception as e:
            self.log.info("ERROR: Unable to retrieve entries from LDAP Server.")
            self.log.info(e)
            raise web.HTTPError(503)
            return

        # Handle the response
        if (len(ldap_result) == 0):
            self.log.info("ERROR: Matching entry for SSO_UID %s not found", sso_uid)
            self.log.info("ERROR: Does user %s have a CERNBox?", sso_uid)
            raise web.HTTPError(403)
            return
        if (len(ldap_result) > 1):
            self.log.info("ERROR: More than one matching entry found for SSO_UID %s", sso_uid)
            raise web.HTTPError(401)
            return
        try:
            unix_user = getattr(ldap_result[0], unix_user_attrname).value
            if approved_key:
                user_to_be_approved = getattr(ldap_result[0], approved_key).value
        except:
            self.log.info("ERROR: Something went wrong parsing the LDAP response for SSO_UID: %s", sso_uid)
            raise web.HTTPError(401)
            return

        if list_approved_users and user_to_be_approved:
            if not user_to_be_approved in list_approved_users:
                self.log.info("ERROR: User not authorized for SSO_UID: %s, EMAIL_ADDRESS: %s", sso_uid, user_to_be_approved)
                raise web.HTTPError(401)
                return

        # From now on, use the Unix uid instead of the SSO one
        self.log.info("INFO: User logged in %s", sso_uid)
        self.log.info("INFO: SSO user %s mapped to %s", sso_uid, unix_user)
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

