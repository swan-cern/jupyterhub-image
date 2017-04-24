FROM osixia/openldap:1.1.8
MAINTAINER Enrico Bocchi <enrico.bocchi@cern.ch>

# Specify TLS certificate and key
#COPY secrets/openldap.* /container/service/slapd/assets/certs/
#ENV LDAP_TLS_CRT_FILENAME=openldap.crt
#ENV LDAP_TLS_KEY_FILENAME=openldap.key

# Copy a script to add dummy users and admin to LDAP for testing purposes
COPY openldap.d/openldap_addusers.sh /

# Start the LDAP service
CMD /container/tool/run --copy-service
