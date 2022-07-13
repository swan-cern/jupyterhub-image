FROM gitlab-registry.cern.ch/linuxsupport/cs9-base

ARG STATSD_VERSION="3.2.2"
ARG CRYPTOGRAPHY_VERSION="2.3.*"
ARG PYCURL_VERSION="7.43.0.*"
ARG PYPOSTGRES_VERSION="2.8.6"
ARG KUBECTL_VERSION="1.23.0"
ARG JUPYTERHUB_VERSION="1.5.0"
ARG COMMON_ASSETS_TAG="v2.6"

RUN curl -LO https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
	install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl 

RUN yum install -y python3-pip python3-pycurl python3-psycopg2 python3-cryptography unzip sudo && yum clean all

RUN pip3 install statsd==$STATSD_VERSION 

RUN mkdir -p /usr/local/share/jupyterhub/static/swan/ && \
    cd /usr/local/share/jupyterhub/static/swan/ && \
    echo "Downloading Common assests build version: ${COMMON_ASSETS_TAG}" && \
    curl -L -o common.zip https://gitlab.cern.ch/api/v4/projects/25625/jobs/artifacts/$COMMON_ASSETS_TAG/download?job=release-version && \
    unzip common.zip && \
    rm -f common.zip

RUN pip3 install --no-cache \
        keycloakauthenticator==3.0.0 \
        swanculler==0.0.2 \
        swannotificationsservice==0.1.0 \
        jupyterhub==${JUPYTERHUB_VERSION} \
        swanspawner==v0.4.0

ADD ./jupyterhub-extensions/SwanSpawner /tmp/SwanSpawner
WORKDIR /tmp/SwanSpawner
RUN pip install --no-cache .

ADD ./jupyterhub-extensions/SwanHub /tmp/SwanHub
WORKDIR /tmp/SwanHub

RUN pip install --no-cache .

RUN ln -sf /usr/local/bin/swanhub /usr/local/bin/jupyterhub
WORKDIR /
