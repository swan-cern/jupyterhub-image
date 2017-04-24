# Simple EOS Docker file
# Version 0.2
#
# Credits go to Elvin Sindrilaru and József Makai, CERN 2017

FROM centos:7
MAINTAINER Enrico Bocchi <enrico.bocchi@cern.ch>

RUN yum -y --nogpg update


# ----- Pick the preferred EOS version by copying the repo file ----- #
# ==> EOS CITRINE -- EOS 4 Version
COPY eos-storage.d/eos_citrine.repo /etc/yum.repos.d/eos.repo
COPY eos-storage.d/epel_citrine.repo /etc/yum.repos.d/epel.repo
ENV XRD_VERSION 4.5.0

# ==> EOS AQUAMARINE -- EOS 0.3 Version
#COPY eos-storage.d/eos_aquamarine.repo /etc/yum.repos.d/eos.repo
#COPY eos-storage.d/epel_aquamarine.repo /etc/yum.repos.d/epel.repo
#ENV XRD_VERSION 3.3.6


# ----- Install XRootD ----- #
RUN yum -y --nogpg install \
    xrootd-$XRD_VERSION \
    xrootd-client-$XRD_VERSION \
    xrootd-client-libs-$XRD_VERSION \
    xrootd-libs-$XRD_VERSION \
    xrootd-server-devel-$XRD_VERSION \
    xrootd-server-libs-$XRD_VERSION


# ----- Install EOS ----- #
RUN yum -y --nogpg install \
    eos-server eos-testkeytab quarkdb 


# ----- Install sssd to access user account information ----- #
# Note: This will be used by the MGM only
RUN yum -y --nogpg install \
    nscd \
    nss-pam-ldapd \
    openldap-clients


# ----- Copy the configuration files for EOS components ----- #
# Note: Configuration files have to be modified in network/host/domain names so to be 
#		consistent with the configuration of other containers (e.g., SWAN, CERNBox)
ADD eos-storage.d/config/eos.sysconfig /etc/sysconfig/eos
ADD eos-storage.d/config/xrd.cf.* /etc/
ADD eos-storage.d/config/eos_*.sh /
ADD eos-storage.d/configure_eos_namespace.sh /


# ----- Copy the configuration files for user account information ----- #
# Note: This will be used by the MGM only
ADD ldappam.d /etc


#ENTRYPOINT ["/bin/bash"]
