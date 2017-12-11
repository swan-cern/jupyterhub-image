### DOCKER FILE FOR cernbox-mysql IMAGE ###

###
# export RELEASE_VERSION=":v0"
# docker build -t gitlab-registry.cern.ch/cernbox/boxedhub/cernbox-mysql${RELEASE_VERSION} -f cernbox-mysql.Dockerfile .
# docker login gitlab-registry.cern.ch
# docker push gitlab-registry.cern.ch/cernbox/boxedhub/cernbox-mysql${RELEASE_VERSION}
####


# Use the official Docker image for MariaDB
# More at: https://hub.docker.com/r/library/mariadb/
FROM mariadb:5.5
ENTRYPOINT []

MAINTAINER Enrico Bocchi <enrico.bocchi@cern.ch>


# ----- Copy the pre-populated MySQL DB files for CERNBox ----- #
ADD ./cernbox-mysql.d/MySQL.tar.gz /var/lib
RUN chown mysql:mysql -R /var/lib/mysql

# ----- Make a copy of /var/lib/mysql in case this will be stored on a hostPath volume in Kubernetes ----- #
RUN mkdir -p /tmp/var-lib-mysql
RUN cp -r -p /var/lib/mysql/. /tmp/var-lib-mysql


EXPOSE 3306

ADD ./cernbox-mysql.d/start.sh /root/start.sh
CMD ["/bin/bash","/root/start.sh"]

