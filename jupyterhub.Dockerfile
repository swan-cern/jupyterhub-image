#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-#
#       |S|c|i|e|n|c|e| |B|o|x|        #
#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-#

# Docker file for JupyterHub image

# Build and push to Docker registry with:
#   export RELEASE_VERSION=":v0"
#   docker build -t gitlab-registry.cern.ch/cernbox/boxedhub/jupyterhub${RELEASE_VERSION} -f jupyterhub.Dockerfile .
#   docker login gitlab-registry.cern.ch
#   docker push gitlab-registry.cern.ch/cernbox/boxedhub/jupyterhub${RELEASE_VERSION}


FROM gitlab-registry.cern.ch/sciencebox/docker-images/parent-images/base:v0

MAINTAINER Enrico Bocchi <enrico.bocchi@cern.ch>


# ----- Software versions ----- #
#ARG DOCKER_VERSION="-17.03.2.ce"
ARG DOCKER_VERSION="-18.06.1.ce"
#ARG JUPYTERHUB_VERSION="0.8.1"
ARG JUPYTERHUB_VERSION="0.9.4"
ARG LDAPAUTHENTICATOR_VERSION="1.2.2"
ARG DOCKERSPAWNER_VERSION="0.9.1"
ARG KUBESPAWNER_VERSION="0.6.1"


# ----- Install tools for LDAP access ----- #
#TODO: Replace this with sssd
RUN yum -y install \
      nscd \
      nss-pam-ldapd \
      openldap-clients && \
    yum clean all && \
    rm -rf /var/cache/yum
ADD ./ldappam.d/*.conf /etc/
RUN chmod 600 /etc/nslcd.conf
ADD ./ldappam.d/nslcd_foreground.sh /usr/sbin/nslcd_foreground.sh
RUN chmod +x /usr/sbin/nslcd_foreground.sh

# ----- Install httpd ----- #
RUN yum -y install \
      httpd \
      mod_ssl && \
    yum clean all && \
    rm -rf /var/cache/yum

# Disable listen directive from conf/httpd.conf and SSL default config
RUN sed -i "s/Listen 80/#Listen 80/" /etc/httpd/conf/httpd.conf
RUN mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.defaults

##TODO: This should go to HELM and configmaps
# Copy plain+ssl config files and rewrites for shibboleth
ADD ./jupyterhub.d/httpd.d/jupyterhub_plain.conf.template /root/httpd_config/jupyterhub_plain.conf.template
ADD ./jupyterhub.d/httpd.d/jupyterhub_ssl.conf.template /root/httpd_config/jupyterhub_ssl.conf.template
ADD ./jupyterhub.d/httpd.d/jupyterhub_shib.conf.template /root/httpd_config/jupyterhub_shib.conf.template

# Copy SSL certificates
ADD ./secrets/boxed.crt /etc/boxed/certs/boxed.crt
ADD ./secrets/boxed.key /etc/boxed/certs/boxed.key

# ----- Install Shibboleth ----- #
RUN yum -y install \
      shibboleth \
      opensaml-schemas && \
    yum clean all && \
    rm -rf /var/cache/yum

#TODO: Verify the link is really needed (in CERNBox we do not do that)
#RUN ln -s /usr/lib64/shibboleth/mod_shib_24.so /etc/httpd/modules/mod_shib_24.so
#RUN mv /etc/httpd/conf.d/shib.conf /etc/httpd/conf.d/shib.noload
#RUN mv /etc/shibboleth/attribute-map.xml /etc/shibboleth/attribute-map.xml.defaults
#RUN mv /etc/shibboleth/shibboleth2.xml /etc/shibboleth/shibboleth2.defaults

## TODO: Remove this. Should be done in supervisor
## Fix the library path for shibboleth (https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPLinuxRH6)
#ENV LD_LIBRARY_PATH=/opt/shibboleth/lib64



# ----- Install the required packages ----- #
# Install Docker (needed only by docker-compose or single-box deployment)
ADD ./repos/docker-ce.repo /etc/yum.repos.d/docker-ce.repo
RUN yum -y install \
      docker-ce$DOCKER_VERSION && \
    yum clean all && \
    rm -rf /var/cache/yum

# Install nodejs, npm, etc.
RUN yum -y install \
      nodejs \
      npm && \
    yum clean all && \
    rm -rf /var/cache/yum

# Install Python, pip, and related upgrades
RUN yum -y install \
      python36 \
      python36-libs \
      python36-pip \
      python36-setuptools && \
    yum clean all && \
    rm -rf /var/cache/yum

RUN pip3.6 install --upgrade pip

# ----- Install JupyterHub ----- #
# Install JupyterHub with upstream authenticators and spawners
RUN pip install jupyterhub==$JUPYTERHUB_VERSION
RUN npm install -g configurable-http-proxy

RUN pip install jupyterhub-ldapauthenticator==$LDAPAUTHENTICATOR_VERSION        # LDAP auth
RUN pip install dockerspawner==$DOCKERSPAWNER_VERSION                           # Dockerspawner
RUN pip install jupyterhub-kubespawner==$KUBESPAWNER_VERSION                    # Kubespawner

#TODO: NNFP -- Remove and install separately by building on top of the produced image
# Additional authenticator: SSO to LDAP Authenticator
ADD ./jupyterhub.d/WebIdentityHandlers/SSOtoLDAPAuthenticator /tmp/SSOtoLDAPAuthenticator
WORKDIR /tmp/SSOtoLDAPAuthenticator
RUN pip install -r requirements.txt && \
    python3.6 setup.py install

#TODO: NNFP -- Remove and install separately by building on top of the produced image
# Additional authenticator: SSO Remote User Authenticator
ADD ./jupyterhub.d/WebIdentityHandlers/SSORemoteUserAuthenticator /tmp/SSORemoteUserAuthenticator
WORKDIR /tmp/SSORemoteUserAuthenticator
RUN pip install -r requirements.txt && \
    python3.6 setup.py install


# ----- Install CERN customizations ----- #
RUN git clone -b master https://gitlab.cern.ch/swan/common.git /usr/local/share/jupyterhub/static/swan/
##TODO: This is copied from prod. Will go out of sync quickly.
ADD ./jupyterhub.d/style.css /usr/local/share/jupyterhub/static/swan/css/style.css

RUN git clone -b master https://gitlab.cern.ch/swan/jupyterhub.git /srv/jupyterhub/jh_gitlab
# Install CERN Handlers
WORKDIR /srv/jupyterhub/jh_gitlab/CERNHandlers
RUN pip install -r requirements.txt && \
    python3.6 setup.py install
# Install CERN Spawner
WORKDIR /srv/jupyterhub/jh_gitlab/CERNSpawner
RUN pip install -r requirements.txt && \
    python3.6 setup.py install

# Reset current directory
WORKDIR /

# ----- Copy configuration files ----- #
##TODO: This should all be done with HELM

# The spawner form
##TODO: This is copied from prod. Will go out of sync quickly.
ADD ./jupyterhub.d/jupyterhub_form.html /srv/jupyterhub/jupyterhub_form.html

# JupyterHub configuration
#ADD ./jupyterhub.d/jupyterhub_config /srv/jupyterhub/config
ADD ./jupyterhub.d/jupyterhub_config /root/jupyterhub_config


##
##TODO: REVIEW CERN CUSTOMIZATIONS
##
## Install CERN Kube Spawner
#ADD ./jupyterhub.d/CERNKubeSpawner /tmp/CERNKubeSpawner
#WORKDIR /tmp/CERNKubeSpawner
#RUN pip3 install -r requirements.txt && \
#       python3 setup.py install
##

# Copy the list of users with administrator privileges
ADD ./jupyterhub.d/adminslist /srv/jupyterhub/adminslist


## ----- Install supervisord and base configuration file ----- #
##TODO: Installation is done before
#ADD ./supervisord.d/supervisord.conf /etc/supervisord.conf

## Copy Supervisor ini files
#ADD ./supervisord.d/jupyterhub.ini /etc/supervisord.d/jupyterhub.ini
ADD ./supervisord.d/httpd.ini /etc/supervisord.d/httpd.ini
#ADD ./supervisord.d/shibd.ini /etc/supervisord.d/shibd.noload
#ADD ./supervisord.d/nscd.ini /etc/supervisord.d
#ADD ./supervisord.d/nslcd.ini /etc/supervisord.d


##TODO: Log files should be handled differently
## E.g., sidecar container and central collection point
## ----- Run crond under supervisor and copy configuration files for log rotation ----- #
#ADD ./supervisord.d/crond.ini /etc/supervisord.d/crond.noload
#ADD ./logrotate.d/logrotate /etc/cron.hourly/logrotate
#RUN chmod +x /etc/cron.hourly/logrotate

## ----- Install logrotate and copy configuration files ----- #
#RUN yum -y install logrotate
#RUN mv /etc/logrotate.conf /etc/logrotate.defaults
#ADD ./logrotate.d/logrotate.conf /etc/logrotate.conf

## Copy logrotate jobs for JupyterHub
#RUN rm -f /etc/logrotate.d/httpd
#ADD ./logrotate.d/logrotate.jobs.d/httpd /etc/logrotate.d/httpd
#ADD ./logrotate.d/logrotate.jobs.d/shibd /etc/logrotate.d/shibd
#ADD ./logrotate.d/logrotate.jobs.d/jupyterhub /etc/logrotate.d/jupyterhub


# ----- Run the setup script in the container ----- #
ADD ./jupyterhub.d/start.sh /root/start.sh
CMD ["/bin/bash", "/root/start.sh"]

