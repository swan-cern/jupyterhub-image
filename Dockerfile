#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-#
#       |S|c|i|e|n|c|e| |B|o|x|        #
#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-#

# Docker file for JupyterHub image

# Build and push to Docker registry with:
#   export RELEASE_VERSION=":v0"
#   docker build -t gitlab-registry.cern.ch/swan/docker-images/jupyterhub${RELEASE_VERSION} .
#   docker login gitlab-registry.cern.ch
#   docker push gitlab-registry.cern.ch/swan/docker-images/jupyterhub${RELEASE_VERSION}


FROM gitlab-registry.cern.ch/sciencebox/docker-images/parent-images/webserver:v0

LABEL maintainer="swan-admins@cern.ch"


# ----- Software versions ----- #
ARG DOCKER_VERSION="18.06.1.ce"

ARG STATSD_VERSION="3.2.2"
ARG CRYPTOGRAPHY_VERSION="2.3.*"
ARG PYCURL_VERSION="7.43.0.*"
ARG PYPOSTGRES_VERSION="2.8.6"

ARG LDAPAUTHENTICATOR_VERSION="1.3.2"
ARG DUMMYAUTHENTICATOR_VERSION="0.3.1"

ARG JUPYTERHUB_VERSION="1.1.0"
ARG CHP_VERSION="4.2.0"
ARG COMMON_ASSETS_TAG="v2.6"


# ----- Install the required packages ----- #
# Install Docker (needed only by docker-compose or single-box deployment)
ADD ./repos/docker-ce.repo /etc/yum.repos.d/docker-ce.repo
RUN yum -y install \
      docker-ce-$DOCKER_VERSION && \
    yum clean all && \
    rm -rf /var/cache/yum

# Install kS4U
RUN yum -y install \
      kS4U && \
    yum clean all && \
    rm -rf /var/cache/yum

# Install nodejs, npm, etc.
RUN yum -y install \
      nodejs \
      npm \
      gcc \
      unzip && \
    yum clean all && \
    rm -rf /var/cache/yum

# Install Python, pip, and related upgrades
RUN yum -y install \
      python36 \
      python36-libs \
      python36-pip \
      python36-devel \
      python36-setuptools && \
    yum clean all && \
    rm -rf /var/cache/yum

# Add hadoop repo. and install fetchdt
ADD ./repos/hdp7-stable.repo /etc/yum.repos.d/hdp7-stable.repo
RUN yum -y install \
      hadoop-fetchdt && \
    yum clean all && \
    rm -rf /var/cache/yum

# Add openstack repo. and install kubernetes-client, helm
ADD ./repos/openstackclients7-queens-stable.repo /etc/yum.repos.d/openstackclients7-queens-stable.repo
RUN yum -y install \
      kubernetes-client \
      helm && \
    yum clean all && \
    rm -rf /var/cache/yum

# Upgrade pip package manager
RUN pip3.6 install --upgrade pip

# ----- Install JupyterHub ----- #

# Install JupyterHub dependencies for postres db support, pycurl over https and cryptography for auth state
RUN yum install -y \
      libcurl-devel && \
    yum clean all && \
    rm -rf /var/cache/yum

RUN PYCURL_SSL_LIBRARY=nss \
    pip install \
    statsd==$STATSD_VERSION \
    psycopg2-binary==$PYPOSTGRES_VERSION \
    cryptography==$CRYPTOGRAPHY_VERSION \
    pycurl==$PYCURL_VERSION

# Install configurable-http-proxy
RUN npm install -g configurable-http-proxy@$CHP_VERSION

# Install JupyterHub with upstream authenticators and spawners
RUN pip install \
    jupyterhub==$JUPYTERHUB_VERSION \
    jupyterhub-ldapauthenticator==$LDAPAUTHENTICATOR_VERSION \
    jupyterhub-dummyauthenticator==$DUMMYAUTHENTICATOR_VERSION 

RUN mkdir -p /var/log/jupyterhub

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
WORKDIR /

# ----- Install CERN customizations ----- #
# Web GUI
RUN mkdir /usr/local/share/jupyterhub/static/swan/ && \
    cd /usr/local/share/jupyterhub/static/swan/ && \
    echo "Downloading Common assests build version: ${COMMON_ASSETS_TAG}" && \
    wget https://gitlab.cern.ch/api/v4/projects/25625/jobs/artifacts/$COMMON_ASSETS_TAG/download?job=release-version -O common.zip && \
    unzip common.zip && \
    rm -f common.zip

# Install all of our JH extensions
RUN pip install \
        keycloakauthenticator==3.2.1 \
        swanculler==0.0.2 \
        swanhub==0.1.5 \
        swannotificationsservice==0.0.1 \
        swanspawner==0.4.0 \
        kubernetes~=20.13.0

# make jupyterhub execute swanhub instead
RUN ln -sf /usr/local/bin/swanhub /usr/local/bin/jupyterhub

# ----- sssd configuration ----- #
##TODO: This should go to HELM and configmaps
ADD ./sssd.d/sssd.conf /etc/sssd/sssd.conf
RUN chown root:root /etc/sssd/sssd.conf && \
    chmod 0600 /etc/sssd/sssd.conf

# ----- httpd configuration ----- #
# Disable listen directive from conf/httpd.conf and SSL default config
RUN sed -i "s/Listen 80/#Listen 80/" /etc/httpd/conf/httpd.conf && \
    mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.defaults

##TODO: This should go to HELM and configmaps
# Copy plain+ssl config files and rewrites for shibboleth
ADD ./jupyterhub.d/httpd.d/jupyterhub_plain.conf.template /root/httpd_config/jupyterhub_plain.conf.template
ADD ./jupyterhub.d/httpd.d/jupyterhub_ssl.conf.template /root/httpd_config/jupyterhub_ssl.conf.template
ADD ./jupyterhub.d/httpd.d/jupyterhub_shib.conf.template /root/httpd_config/jupyterhub_shib.conf.template

# Copy SSL certificates
ADD ./secrets/boxed.crt /etc/boxed/certs/boxed.crt
ADD ./secrets/boxed.key /etc/boxed/certs/boxed.key

# ----- Shibboleth configuration ----- #
RUN mv /etc/httpd/conf.d/shib.conf /etc/httpd/conf.d/shib.noload && \
    mv /etc/shibboleth/attribute-map.xml /etc/shibboleth/attribute-map.xml.defaults && \
    mv /etc/shibboleth/shibboleth2.xml /etc/shibboleth/shibboleth2.defaults

# ----- jupyterhub configuration ----- #
# The spawner form
##TODO: This is copied from prod. Will go out of sync quickly.
ADD ./jupyterhub.d/jupyterhub_form.complete.html /srv/jupyterhub/jupyterhub_form.complete.html
ADD ./jupyterhub.d/jupyterhub_form.simple.html /srv/jupyterhub/jupyterhub_form.simple.html
ADD ./jupyterhub.d/options_form_config.json /srv/jupyterhub/options_form_config.json

# JupyterHub configuration
##TODO: This should go to HELM and configmaps
ADD ./jupyterhub.d/jupyterhub_config /root/jupyterhub_config

# Copy the list of users with administrator privileges
ADD ./jupyterhub.d/adminslist /srv/jupyterhub/adminslist

# ----- Copy supervisord files ----- #
RUN mv /etc/supervisord.d/sssd.noload /etc/supervisord.d/sssd.ini && \
    mv /etc/supervisord.d/httpd.noload /etc/supervisord.d/httpd.ini
ADD ./supervisord.d/jupyterhub.ini /etc/supervisord.d/jupyterhub.ini

# need to install helm v2.17 to set the right helm2 repos, then remove as incompatible with
# the version in the cluster... to be cleaned up once we move to helm3 in sparkk8s
RUN curl https://get.helm.sh/helm-v2.17.0-linux-amd64.tar.gz | tar xzvf - -C /usr/bin --strip=1 linux-amd64/helm && \
	helm init --client-only && \
	curl https://get.helm.sh/helm-v2.16.7-linux-amd64.tar.gz | tar xzvf - -C /usr/bin --strip=1 linux-amd64/helm

# ----- Run the setup script in the container ----- #
ADD ./jupyterhub.d/start.sh /root/start.sh
CMD ["/bin/bash", "/root/start.sh"]

