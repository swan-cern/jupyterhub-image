FROM gitlab-registry.cern.ch/linuxsupport/alma9-base:20231001-1

LABEL maintainer="swan-admins@cern.ch"

# ----- Install JupyterHub dependencies ----- #

# Install JH dependencies for PostgreSQL db support, pycurl over https

RUN dnf install -y python3-psycopg2 \
                   python3-pycurl && \
    dnf clean all && rm -rf /var/cache/dnf

# ----- Install CERN customizations ----- #

# Install support packages
RUN dnf install -y python3-pip \
                   # needed by swanculler
                   sudo && \
    dnf clean all && rm -rf /var/cache/dnf

# Install JH extensions
RUN pip3 install --no-cache \
         keycloakauthenticator==4.0.0 \
         swanculler==1.0.0 \
         swanhub==1.0.0 \
         swannotificationsservice==1.0.0 \
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
ARG COMMON_ASSETS_TAG="v2.6"
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
