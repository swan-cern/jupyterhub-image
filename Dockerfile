FROM gitlab-registry.cern.ch/linuxsupport/alma9-base:20240801-1

LABEL maintainer="swan-admins@cern.ch"

# ----- Install JupyterHub dependencies ----- #

# Install JH dependencies for PostgreSQL db support, pycurl over https

RUN dnf install -y python3-psycopg2 \
                   python3-pycurl && \
    dnf clean all && rm -rf /var/cache/dnf

# ----- Install CERN customizations ----- #

# Install support packages
RUN dnf install -y python3-pip \
                   # needed by kS4U
                   perl-Data-Dumper \
                   # needed by swanculler
                   sudo && \
    dnf clean all && rm -rf /var/cache/dnf

# Install JH extensions
RUN pip3 install --no-cache \
         keycloakauthenticator==4.0.6 \
         swanculler==1.0.7 \
         swanhub==1.0.16 \
         swannotificationsservice==1.0.4 \
         swanspawner==1.2.42

# Install kS4U
ADD ./bin/kS4U.pl /usr/bin/kS4U
ADD ./conf/krb5.conf /etc/krb5.conf
RUN chmod +x /usr/bin/kS4U && \
    dnf install -y perl-Authen-Krb5 && \
    dnf clean all && rm -rf /var/cache/dnf

# Install kubectl and helm (for sparkk8s_token.sh)
RUN curl -LO "https://dl.k8s.io/release/v1.34.4/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl && \
    curl -fsSL https://get.helm.sh/helm-v4.1.3-linux-amd64.tar.gz | tar xz && \
    install -o root -g root -m 0755 linux-amd64/helm /usr/local/bin/helm && rm -rf linux-amd64

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
