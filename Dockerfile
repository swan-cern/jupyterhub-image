ARG PYCURL_VERSION="7.43.0.6"

######### Helper build stage for pycurl #########

FROM gitlab-registry.cern.ch/linuxsupport/alma9-base:20221201-1 AS builder

ARG PYCURL_VERSION

WORKDIR /tmp

RUN dnf group install -y "Development Tools"

RUN dnf install -y python3-pip \
                   python3-devel \
                   libcurl-devel \
                   openssl-devel

RUN pip3 install --no-cache wheel && \
    PYCURL_SSL_LIBRARY=openssl \
    pip3 wheel --no-cache \
         pycurl==$PYCURL_VERSION


################ Main build stage ###############

FROM gitlab-registry.cern.ch/linuxsupport/alma9-base:20221201-1

LABEL maintainer="swan-admins@cern.ch"

# ----- Software versions ----- #

ARG PYCURL_VERSION
ARG PYPOSTGRES_VERSION="2.8.6"
ARG CRYPTOGRAPHY_VERSION="2.3.*"
ARG SQLALCHEMY_VERSION="1.4.46"

ARG JUPYTERHUB_VERSION="1.4.2"

ARG KUBECLIENT_VERSION="20.13.0"

ARG COMMON_ASSETS_TAG="v2.6"

# ----- Install JupyterHub ----- #

# Install support packages
RUN dnf install -y python3-pip \
                   # needed by pycurl
                   openssl \
                   # needed by swanculler
                   sudo && \
    dnf clean all && rm -rf /var/cache/dnf

# Install JH dependencies for PostgreSQL db support, pycurl over https and cryptography for auth state
ARG PYCURL_WHEEL="/tmp/pycurl-${PYCURL_VERSION}-cp39-cp39-linux_x86_64.whl"

COPY --from=builder $PYCURL_WHEEL $PYCURL_WHEEL

RUN pip3 install --no-cache \
         $PYCURL_WHEEL \
         psycopg2-binary==$PYPOSTGRES_VERSION \
         cryptography==$CRYPTOGRAPHY_VERSION \
         # current version of JH is not compatible with sqlalchemy v2
         # https://github.com/jupyterhub/jupyterhub/issues/4312
         sqlalchemy==$SQLALCHEMY_VERSION

# Install Kubernetes client (for kubespawner)
RUN pip3 install --no-cache kubernetes==${KUBECLIENT_VERSION}

# Install JH
RUN pip3 install --no-cache jupyterhub==${JUPYTERHUB_VERSION}

# ----- Install CERN customizations ----- #

# Install JH extensions
RUN pip3 install --no-cache \
         keycloakauthenticator==3.3.0 \
         swanculler==0.0.2 \
         swanhub==0.1.6 \
         swannotificationsservice==0.0.1 \
         swanspawner==0.4.2

# TODO: Install kS4U

# Add Hadoop repo and install fetchdt
ADD ./repos/hdp7-stable.repo /etc/yum.repos.d/hdp7-stable.repo
RUN dnf -y install hadoop-fetchdt && \
    dnf clean all && rm -rf /var/cache/dnf

# Web GUI (CSS, logo)
RUN dnf install -y unzip wget && \
    mkdir /usr/local/share/jupyterhub/static/swan/ && \
    cd /usr/local/share/jupyterhub/static/swan/ && \
    echo "Downloading Common assests build version: ${COMMON_ASSETS_TAG}" && \
    wget https://gitlab.cern.ch/api/v4/projects/25625/jobs/artifacts/$COMMON_ASSETS_TAG/download?job=release-version -O common.zip && \
    unzip common.zip && \
    dnf remove -y unzip wget && \
    dnf clean all && rm -rf /var/cache/dnf \
    rm -f common.zip

# Make jupyterhub execute swanhub instead
RUN ln -sf /usr/local/bin/swanhub /usr/local/bin/jupyterhub