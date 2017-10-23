### DOCKER FILE FOR jupyterhub IMAGE ###

###
# export RELEASE_VERSION=":v0"
# docker build -t gitlab-registry.cern.ch/cernbox/boxedhub/jupyterhub${RELEASE_VERSION} -f jupyterhub.Dockerfile .
# docker login gitlab-registry.cern.ch
# docker push gitlab-registry.cern.ch/cernbox/boxedhub/jupyterhub${RELEASE_VERSION}
####


FROM cern/cc7-base:20170920

MAINTAINER Enrico Bocchi <enrico.bocchi@cern.ch>


# ----- Set environment and language ----- #
ENV DEBIAN_FRONTEND noninteractive
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8


# ----- Install the required packages ----- #
# Install Pyhon 3.4, pip and related upgrades
RUN yum install -y \
	wget \
        git \
	sudo

# Install Pyhon 3.4, pip, ...
RUN yum -y install \
	python34 \
	python34-pip
RUN pip3 install --upgrade pip

# Install Tornado, NodeJS, ...
RUN yum install -y \
	python34-sqlalchemy \
	python34-tornado \
	python34-jinja2 \
	python34-traitlets \
	python34-requests \
	nodejs
RUN npm install -g configurable-http-proxy

# Install Docker and JupyterHub
RUN wget -q https://get.docker.com -O /tmp/getdocker.sh && \
    bash /tmp/getdocker.sh
RUN pip3 install jupyterhub==0.7.2
RUN pip3 install git+git://github.com/jupyterhub/dockerspawner.git@92a7ca676997dc77b51730ff7626d8fcd31860da	# Dockerspawner
#TODO: Add here kubespawner


# ----- Copy TLS certificates to serve the Hub over HTTPS ----- #
# NOTE: These certificates might be overridden at run time by the ones available in uboxed/certs/boxed.{key,crt}
RUN mkdir -p /srv/jupyterhub/
ADD ./secrets/boxed.crt /srv/jupyterhub/secrets/jupyterhub.crt
ADD ./secrets/boxed.key /srv/jupyterhub/secrets/jupyterhub.key
RUN chmod 700 /srv/jupyterhub/secrets && \
    chmod 600 /srv/jupyterhub/secrets/*


# ----- Install CERN customizations ----- #
# Note: need to clone the whole JH repository from GitLab (done by SetupHost.sh), 
# 	but access is not granted to 3rd parties 

# Install CERN Spawner
ADD ./jupyterhub.d/jupyterhub-dmaas/CERNSpawner /jupyterhub-dmaas/CERNSpawner
WORKDIR /jupyterhub-dmaas/CERNSpawner
RUN pip3 install -r requirements.txt && \
	python3 setup.py install

# Install CERN Handlers
ADD ./jupyterhub.d/jupyterhub-dmaas/CERNHandlers /jupyterhub-dmaas/CERNHandlers
WORKDIR /jupyterhub-dmaas/CERNHandlers
RUN pip3 install -r requirements.txt && \
	python3 setup.py install

# Copy the templates and the logos
ADD ./jupyterhub.d/jupyterhub-dmaas/templates /jupyterhub-dmaas/templates
ADD ./jupyterhub.d/jupyterhub-dmaas/logo /jupyterhub-dmaas/logo
ADD ./jupyterhub.d/jupyterhub-puppet/code/templates/jupyterhub/jupyterhub_form.html.erb /srv/jupyterhub/jupyterhub_form.html

# Copy the bootstrap script
ADD ./jupyterhub.d/jupyterhub-dmaas/scripts/start_jupyterhub.py /jupyterhub-dmaas/scripts/start_jupyterhub.py


# ----- Install LDAP authenticator ----- #
RUN pip3 install git+git://github.com/jupyterhub/ldapauthenticator.git@f3b2db14bfb591df09e05f8922f6041cc9c1b3bd


# ----- Install sssd to access user account information ----- #
RUN yum install -y \
	nscd \
	nss-pam-ldapd \
	openldap-clients
ADD ./ldappam.d /etc
RUN chmod 600 /etc/nslcd.conf

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


# ----- Copy configuration files and reset current directory ----- #
# Copy the list of users with administrator privileges
ADD ./jupyterhub.d/adminslist /srv/jupyterhub/adminslist

# Copy the configuration for JupyterHub
ADD ./jupyterhub.d/jupyterhub_config.docker.py /srv/jupyterhub/jupyterhub_config.docker.py
ADD ./jupyterhub.d/jupyterhub_config.kubernetes.py /srv/jupyterhub/jupyterhub_config.kubernetes.py



#RUN yum install -y \
#        vim \
#        nano \
#        less \
#        net-tools \
#        bind-utils \
#        nmap \
#        tcpdump

### Kubernetes spawner for testing
#RUN pip3 install git+git://github.com/jupyterhub/kubespawner.git@ae1c6d6f58a45c2ba4b9e2fa81d50b16503f9874	# Kubespawner


# Install CERN Kube Spawner
#ADD ./jupyterhub.d/jupyterhub-dmaas/CERNKubeSpawner /jupyterhub-dmaas/CERNKubeSpawner
#WORKDIR /jupyterhub-dmaas/CERNKubeSpawner
#RUN pip3 install -r requirements.txt && \
#        python3 setup.py install

#ADD ./jupyterhub.d/jupyterhub_config.kubespawner.py /srv/jupyterhub/jupyterhub_config.kubespawner.py


# ----- Run the setup script in the container ----- #
WORKDIR /
ADD ./jupyterhub.d/start.sh /root/start.sh
CMD ["/bin/bash", "/root/start.sh"]

