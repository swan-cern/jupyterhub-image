### DOCKER FILE FOR jupyterhub IMAGE ###

###
# export RELEASE_VERSION=":v0"
# docker build -t gitlab-registry.cern.ch/cernbox/boxedhub/jupyterhub${RELEASE_VERSION} -f jupyterhub.Dockerfile .
# docker login gitlab-registry.cern.ch
# docker push gitlab-registry.cern.ch/cernbox/boxedhub/jupyterhub${RELEASE_VERSION}
###


FROM cern/cc7-base:20180316

MAINTAINER Enrico Bocchi <enrico.bocchi@cern.ch>


# ----- Set environment and language ----- #
ENV DEBIAN_FRONTEND noninteractive
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8


# ----- Install the basics ----- #
RUN yum -y install \
	wget \
	git \
	sudo


# ----- Install supervisord and base configuration file ----- #
RUN yum -y install supervisor
ADD ./supervisord.d/supervisord.conf /etc/supervisord.conf


# ----- Install the required packages ----- #
# Install Pyhon 3.4, pip and related upgrades
RUN yum -y install \
	python34 \
	python34-pip
RUN pip3 install --upgrade pip

# Install Tornado, NodeJS, ...
RUN yum -y install \
	python34-sqlalchemy \
	python34-tornado \
	python34-jinja2 \
	python34-traitlets \
	python34-requests \
	nodejs
RUN npm install -g configurable-http-proxy

# Install Docker, JupyterHub, spawners, and authenticators
RUN wget -q https://get.docker.com -O /tmp/getdocker.sh && \
    bash /tmp/getdocker.sh
RUN pip3 install jupyterhub==0.7.2

RUN pip3 install git+git://github.com/jupyterhub/dockerspawner.git@92a7ca676997dc77b51730ff7626d8fcd31860da	# Dockerspawner
RUN pip3 install git+git://github.com/jupyterhub/kubespawner.git@ae1c6d6f58a45c2ba4b9e2fa81d50b16503f9874	# Kubespawner

RUN pip3 install git+git://github.com/jupyterhub/ldapauthenticator.git@f3b2db14bfb591df09e05f8922f6041cc9c1b3bd	# LDAP auth
RUN pip3 install git+git://github.com/cwaldbieser/jhub_remote_user_authenticator.git				# REMOTE_USER auth
ADD ./jupyterhub.d/jupyterhub_CERN/1afb53edbf1ede3650b003aa3cd7e24f /tmp


# ----- Install CERN customizations ----- #
# Install SSO to LDAP Authenticator
ADD ./jupyterhub.d/WebIdentityHandlers/SSOtoLDAPAuthenticator /tmp/SSOtoLDAPAuthenticator
WORKDIR /tmp/SSOtoLDAPAuthenticator
RUN pip3 install -r requirements.txt && \
        python3 setup.py install

# Install SSO Remote User Authenticator
ADD ./jupyterhub.d/WebIdentityHandlers/SSORemoteUserAuthenticator /tmp/SSORemoteUserAuthenticator
WORKDIR /tmp/SSORemoteUserAuthenticator
RUN pip3 install -r requirements.txt && \
        python3 setup.py install

# Install CERN Spawner
ADD ./jupyterhub.d/jupyterhub_CERN/CERNSpawner.tar.gz /tmp
WORKDIR /tmp/CERNSpawner
RUN pip3 install -r requirements.txt && \
	python3 setup.py install

# Install CERN Handlers
ADD ./jupyterhub.d/jupyterhub_CERN/CERNHandlers.tar.gz /tmp
WORKDIR /tmp/CERNHandlers
RUN pip3 install -r requirements.txt && \
        python3 setup.py install

# CERN Logos, Templates, Session Form, Start Script
ADD ./jupyterhub.d/jupyterhub_CERN/CERNTemplates.tar.gz /srv/jupyterhub
ADD ./jupyterhub.d/jupyterhub_CERN/CERNLogos.tar.gz /srv/jupyterhub
ADD ./jupyterhub.d/jupyterhub_CERN/jupyterhub_form.html.erb /srv/jupyterhub/jupyterhub_form.html
ADD ./jupyterhub.d/jupyterhub_CERN/start_jupyterhub.py /srv/jupyterhub/start_jupyterhub.py


# ----- Install and related mods ----- #
RUN yum -y install \
        httpd \
        mod_ssl
# Disable listen directive from conf/httpd.conf and SSL default config
RUN sed -i "s/Listen 80/#Listen 80/" /etc/httpd/conf/httpd.conf
RUN mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.defaults
#Copy plain+ssl config files and rewrites for shibboleth
ADD ./jupyterhub.d/httpd.d/jupyterhub_plain.conf.template /root/httpd_config/jupyterhub_plain.conf.template
ADD ./jupyterhub.d/httpd.d/jupyterhub_ssl.conf.template /root/httpd_config/jupyterhub_ssl.conf.template
ADD ./jupyterhub.d/httpd.d/jupyterhub_shib.conf.template /root/httpd_config/jupyterhub_shib.conf.template
#Copy secrets for SSL
ADD ./secrets/boxed.crt /etc/boxed/certs/boxed.crt
ADD ./secrets/boxed.key /etc/boxed/certs/boxed.key


# ----- Install shibboleth ----- #
RUN yum -y install \
        shibboleth \
        opensaml-schemas \
        xmltooling-schemas
RUN ln -s /usr/lib64/shibboleth/mod_shib_24.so /etc/httpd/modules/mod_shib_24.so
RUN mv /etc/httpd/conf.d/shib.conf /etc/httpd/conf.d/shib.noload
RUN mv /etc/shibboleth/attribute-map.xml /etc/shibboleth/attribute-map.xml.defaults
RUN mv /etc/shibboleth/shibboleth2.xml /etc/shibboleth/shibboleth2.defaults
# Fix the library path for shibboleth (https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPLinuxRH6)
ENV LD_LIBRARY_PATH=/opt/shibboleth/lib64


# ----- Install sssd to access user account information ----- #
RUN yum -y install \
	nscd \
	nss-pam-ldapd \
	openldap-clients
ADD ./ldappam.d/*.conf /etc/
RUN chmod 600 /etc/nslcd.conf
ADD ./ldappam.d/nslcd_foreground.sh /usr/sbin/nslcd_foreground.sh
RUN chmod +x /usr/sbin/nslcd_foreground.sh

# Needed to bind to CERN ldap
#RUN yum -y install \
#		sssd \
#		nss \
#		pam \
#		policycoreutils \
#		authconfig
# See: http://linux.web.cern.ch/linux/docs/account-mgmt.shtml
#RUN wget -q http://linux.web.cern.ch/linux/docs/sssd.conf.example -O /etc/sssd/sssd.conf && \
#	chown root:root /etc/sssd/sssd.conf && \
#	chmod 0600 /etc/sssd/sssd.conf && \
#	restorecon /etc/sssd/sssd.conf
#RUN authconfig --enablesssd --enablesssdauth --update 2>/dev/null


# ----- Extra files required by integration with SSO solutions ----- #

# 1. CERN-specific shibboleth config and attributes
ADD ./shibd.d/attribute-map.xml /root/CERN_SSO/attribute-map.xml
ADD ./shibd.d/ADFS-metadata.xml /root/CERN_SSO/ADFS-metadata.xml
ADD ./jupyterhub.d/shibboleth2.yaml.template /root/CERN_SSO/shibboleth2.yaml.template

# NOTE: Integration with SSO solutions might require a custom authenticator!



# ----- Copy configuration files and reset current directory ----- #
# Copy the list of users with administrator privileges
ADD ./jupyterhub.d/adminslist /srv/jupyterhub/adminslist

# Copy the configuration files for JupyterHub
ADD ./jupyterhub.d/jupyterhub_config /root/jupyterhub_config


# ----- Run the setup script in the container ----- #
WORKDIR /
ADD ./jupyterhub.d/start.sh /root/start.sh
ADD ./supervisord.d/nscd.ini /etc/supervisord.d
ADD ./supervisord.d/nslcd.ini /etc/supervisord.d
ADD ./supervisord.d/shibd.ini /etc/supervisord.d/shibd.noload
ADD ./supervisord.d/httpd.ini /etc/supervisord.d
ADD ./supervisord.d/jupyterhub.ini /etc/supervisord.d
CMD ["/bin/bash", "/root/start.sh"]

