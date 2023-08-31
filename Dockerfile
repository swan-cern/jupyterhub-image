
ARG WHEEL_DIR="/tmp/wheels"

######### Helper build stage for pycurl #########

FROM gitlab-registry.cern.ch/linuxsupport/alma9-base:20221201-1 AS builder

ARG WHEEL_DIR
ARG PYCURL_VERSION="7.43.0.6"

RUN dnf group install -y "Development Tools"

RUN dnf install -y python3-pip \
                   python3-devel \
                   libcurl-devel \
                   openssl-devel

RUN pip3 install --no-cache wheel && \
    PYCURL_SSL_LIBRARY=openssl \
    pip3 wheel --no-cache \
         --wheel-dir=$WHEEL_DIR \
         pycurl==$PYCURL_VERSION


################ Main build stage ###############

FROM gitlab-registry.cern.ch/linuxsupport/alma9-base:20221201-1

LABEL maintainer="swan-admins@cern.ch"

ARG WHEEL_DIR

# ----- Software versions ----- #

ARG PYPOSTGRES_VERSION="2.8.6"
ARG CRYPTOGRAPHY_VERSION="2.3.*"
ARG SQLALCHEMY_VERSION="1.4.46"

ARG KUBECLIENT_VERSION="20.13.0"

ARG COMMON_ASSETS_TAG="v2.6"

# ----- Install JupyterHub dependencies ----- #

# Install support packages
RUN dnf install -y python3-pip \
                   # needed by pycurl
                   openssl \
                   # needed by swanculler
                   sudo && \
    dnf clean all && rm -rf /var/cache/dnf

# Install JH dependencies for PostgreSQL db support, pycurl over https and cryptography for auth state
COPY --from=builder $WHEEL_DIR $WHEEL_DIR

RUN pip3 install --no-cache \
         --no-index \
         --find-links=$WHEEL_DIR \
         pycurl && \
         rm -rf $WHEEL_DIR

RUN pip3 install --no-cache \
         psycopg2-binary==$PYPOSTGRES_VERSION \
         cryptography==$CRYPTOGRAPHY_VERSION \
         # current version of JH is not compatible with sqlalchemy v2
         # https://github.com/jupyterhub/jupyterhub/issues/4312
         sqlalchemy==$SQLALCHEMY_VERSION

# Install Kubernetes client (for kubespawner)
RUN pip3 install --no-cache kubernetes==${KUBECLIENT_VERSION}

# ----- Install CERN customizations ----- #

# Install JH extensions
RUN pip3 install --no-cache \
         keycloakauthenticator==3.3.0 \
         swanculler==0.0.3 \
         swanhub==0.1.6 \
         swannotificationsservice==0.0.1 \
         swanspawner==0.5.0

# Install kS4U
ADD ./bin/kS4U.pl /usr/bin/kS4U
ADD ./conf/krb5.conf /etc/krb5.conf
RUN chmod +x /usr/bin/kS4U && \
    dnf install -y perl-Authen-Krb5 && \
    dnf clean all && rm -rf /var/cache/dnf

# Install kubectl and helm (for sparkk8s_token.sh)
ADD ./repos/kubernetes9al-stable.repo /etc/yum.repos.d/kubernetes9al-stable.repo
RUN dnf install -y kubernetes-client && \
    dnf clean all && rm -rf /var/cache/dnf
# TODO: Replace this by the installation of the helm system package above
# Install helm v2 temporarily until the k8s Spark cluster is updated to a more
# recent k8s version -- helm v3 does not work with the current k8s version
RUN cd /tmp && \
    curl -LO https://git.io/get_helm.sh && \
    chmod 700 get_helm.sh && \
    HELM_INSTALL_DIR=/usr/bin ./get_helm.sh --version v2.16.7 && \
    rm get_helm.sh

# Web GUI (CSS, logo)
RUN dnf install -y unzip && \
    mkdir /usr/local/share/jupyterhub/static/swan/ && \
    cd /usr/local/share/jupyterhub/static/swan/ && \
    echo "Downloading Common assests build version: ${COMMON_ASSETS_TAG}" && \
    curl -L https://gitlab.cern.ch/api/v4/projects/25625/jobs/artifacts/$COMMON_ASSETS_TAG/download?job=release-version -o common.zip && \
    unzip common.zip && \
    dnf remove -y unzip && \
    dnf clean all && rm -rf /var/cache/dnf \
    rm -f common.zip

# Add scripts for culler (EOS tickets) and token generation
ADD ./scripts/culler /srv/jupyterhub/culler
RUN chmod 544 /srv/jupyterhub/culler/*.sh
ADD ./scripts/private /srv/jupyterhub/private
RUN chmod 544 /srv/jupyterhub/private/*.sh

# Make jupyterhub execute swanhub instead
RUN ln -sf /usr/local/bin/swanhub /usr/local/bin/jupyterhub

# ----- Align with upstream image ----- #

# Install tini
RUN curl -L https://github.com/krallin/tini/releases/download/v0.19.0/tini -o tini && \
    echo "93dcc18adc78c65a028a84799ecf8ad40c936fdfc5f2a57b1acda5a8117fa82c  tini" | sha256sum -c - && \
    mv tini /usr/local/bin/tini && \
    chmod +x /usr/local/bin/tini

# Install py-spy
RUN pip3 install --no-cache \
         py-spy

EXPOSE 8081
ENTRYPOINT ["tini", "--"]
CMD ["jupyterhub", "--config", "/usr/local/etc/jupyterhub/jupyterhub_config.py"]
