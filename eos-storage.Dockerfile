# Simple EOS Docker file
# Version 0.2
#
# Credits go to Elvin Sindrilaru and József Makai, CERN 2017

#FROM cern/slc6-base:20170406
#FROM cern/cc7-base:20170113
#FROM centos:7
FROM centos:6.9

MAINTAINER Enrico Bocchi <enrico.bocchi@cern.ch>

RUN yum -y install yum-plugin-ovl # See http://unix.stackexchange.com/questions/348941/rpmdb-checksum-is-invalid-trying-to-install-gcc-in-a-centos-7-2-docker-image
RUN yum -y --nogpg update


# ----- Pick the preferred EOS version by copying the repo file ----- #
# ==> EOS CITRINE -- EOS 4 Version
#COPY eos-storage.d/eos_citrine.repo /etc/yum.repos.d/eos.repo
#COPY eos-storage.d/epel_citrine.repo /etc/yum.repos.d/epel.repo
#ENV XRD_VERSION -4.5.0

# ==> EOS AQUAMARINE -- EOS 0.3 Version
COPY eos-storage.d/eos_aquamarine.repo /etc/yum.repos.d/eos.repo
COPY eos-storage.d/epel_aquamarine.repo /etc/yum.repos.d/epel.repo
COPY eos-storage.d/eos-ai.repo /etc/yum.repos.d/eos-ai.repo

# pin the versions (set to empty string to unpin and get the latest version available)
ENV XRD_VERSION -3.3.6 
ENV EOS_VERSION -0.3.231


# ----- Install XRootD ----- #
RUN yum -y --nogpg install \
    xrootd$XRD_VERSION \
    xrootd-client$XRD_VERSION \
    xrootd-client-libs$XRD_VERSION \
    xrootd-libs$XRD_VERSION \
    xrootd-server-devel$XRD_VERSION \
    xrootd-server-libs$XRD_VERSION


# ----- Install EOS ----- #
RUN yum -y --nogpg install \
    eos-server$EOS_VERSION eos-client$EOS_VERSION eos-testkeytab$EOS_VERSION quarkdb 

# NOTE: you may want to pin the version: eos-server-0.3.240 eos-client-0.3.240

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
#CMD ["/bin/bash"]
