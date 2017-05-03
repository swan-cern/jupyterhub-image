# Dockerfile to create the container for JupyterHub
# Use CERN cc7 as base image for JupyterHub
FROM cern/cc7-base:20170113

MAINTAINER Enrico Bocchi <enrico.bocchi@cern.ch>


# ----- Set environment and language ----- #
ENV DEBIAN_FRONTEND noninteractive
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
# ----- ----- #

RUN yum -y install yum-plugin-ovl # See http://unix.stackexchange.com/questions/348941/rpmdb-checksum-is-invalid-trying-to-install-gcc-in-a-centos-7-2-docker-image


# ----- Install the required packages ----- #
RUN yum -y update

# Install Pyhon 3.4, pip and related upgrades
RUN yum -y install \
		python34 \
		python34-pip
#RUN pip3 install --upgrade pip

# Install Tornado, NodeJS, etc.
RUN yum install -y \
		python34-sqlalchemy \
		python34-tornado \
		python34-jinja2 \
		python34-traitlets \
		python34-requests \
		nodejs \
		sudo

# Install Docker, DockerSpawner, and JupyterHub
RUN npm install -g configurable-http-proxy
RUN yum install -y \
		wget \
		git
RUN wget -q https://get.docker.com -O /tmp/getdocker.sh && \
	bash /tmp/getdocker.sh && \
	rm /tmp/getdocker.sh
RUN pip3 install jupyterhub==0.5
RUN pip3 install git+git://github.com/jupyterhub/dockerspawner.git@75dd1dc8019119cfa851a510c1beeaae50bce9ae
# ----- ----- #


# ----- Copy TLS certificates to serve the Hub over HTTPS ----- #
# Copy the TLS ceritificate to reach JupyterHub over HTTPS
# TODO: This should be modified in case we will have proper ceritificates
# TODO:	for the time being, use self-signed ceritificates
RUN mkdir -p /srv/jupyterhub/
COPY ./secrets/*.crt /srv/jupyterhub/secrets/jupyterhub.crt
COPY ./secrets/*.key /srv/jupyterhub/secrets/jupyterhub.key
RUN chmod 700 /srv/jupyterhub/secrets && \
    chmod 600 /srv/jupyterhub/secrets/*


# ----- Install CERN customizations ----- #
# Note: need to clone the whole JH repository from GitLab (done by SetupHost.sh), 
# 	but access is not granted to 3rd parties 

# Install CERN Spawner
COPY jupyterhub.d/jupyterhub-dmaas/CERNSpawner /jupyterhub-dmaas/CERNSpawner
WORKDIR /jupyterhub-dmaas/CERNSpawner
RUN pip3 install -r requirements.txt && \
	python3 setup.py install

# Install CERN Handlers
COPY jupyterhub.d/jupyterhub-dmaas/CERNHandlers /jupyterhub-dmaas/CERNHandlers
WORKDIR /jupyterhub-dmaas/CERNHandlers
RUN pip3 install -r requirements.txt && \
	python3 setup.py install

# Copy the templates and the logos
COPY jupyterhub.d/jupyterhub-dmaas/templates /jupyterhub-dmaas/templates
COPY jupyterhub.d/jupyterhub-dmaas/logo /jupyterhub-dmaas/logo
COPY jupyterhub.d/jupyterhub-puppet/code/templates/jupyterhub/jupyterhub_form.html.erb /srv/jupyterhub/jupyterhub_form.html

# Copy the bootstrap script
COPY jupyterhub.d/jupyterhub-dmaas/scripts/start_jupyterhub.py /jupyterhub-dmaas/scripts/start_jupyterhub.py
# ----- ----- #


# ----- Install Authentication methods ----- #
# Install OAuthenticator
#RUN pip3 install oauthenticator

# Install LDAP Authenticator
RUN pip3 install git+git://github.com/jupyterhub/ldapauthenticator.git@358db134e6b49139745b8d7856f323eb257a207e
# ----- ----- #


# ----- Install sssd to access user account information ----- #
# Needed by dockerspawner/systemuserspawner.py
RUN yum install -y \
		nscd \
		nss-pam-ldapd \
		openldap-clients
ADD ./ldappam.d /etc

# Needed to bind to CERN ldap
#RUN yum install -y \
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
# ----- ----- #


# ----- Copy configuration files and reset current directory ----- #
# Copy the list of users with administrator privileges
COPY jupyterhub.d/adminslist /srv/jupyterhub/adminslist

# Copy the configuration for JupyterHub
COPY jupyterhub.d/jupyterhub_config.py /srv/jupyterhub/jupyterhub_config.py

# ----- Run the setup script in the container ----- #
WORKDIR /
COPY jupyterhub.d/jupyterhub_startJH.sh /root/jupyterhub_startJH.sh
CMD ["/bin/bash", "/root/jupyterhub_startJH.sh"]
