#!/usr/bin/bash

USER_Ns=`seq 0 9`
ACTION_FILE='/tmp/action.ldif'
ldapadd_macro  () {
  ldapadd -x -H ldap://ldap -D "cn=admin,dc=example,dc=org" -w admin -f $ACTION_FILE
}

# Wait for the ldap server to be up and running
echo "Waiting for LDAP server to be ready..."
until ldapsearch -x -H ldap://ldap -D "cn=admin,dc=example,dc=org" -w admin -b dc=example,dc=org &>/dev/null; 
do
  sleep 10s;
done

# Create entries for dummy users on the ldap server
echo "Configuring demo users on LDAP server..."
for i in $USER_Ns;
do
	# Make a ldif file for each user
	echo "dn: uid=user$i,dc=example,dc=org
	objectclass: top
	objectclass: account
	objectclass: posixAccount
	objectclass: shadowAccount
	cn: user$i
	uid: user$i
	uidNumber: 100$i
	gidNumber: 100$i
	homeDirectory: /home/user$i
	loginShell: /bin/bash
	gecos: user$i
	userPassword: {crypt}x
	shadowLastChange: 0
	shadowMax: 0
	shadowWarning: 0" > $ACTION_FILE
	# Add the user and set a password for her
	ldapadd_macro
	ldappasswd -x -H ldap://ldap -D "cn=admin,dc=example,dc=org" -w admin "uid=user$i,dc=example,dc=org" -s test$i
done

# Also add a dummy administrator
echo "dn: uid=dummy_admin,dc=example,dc=org
objectclass: top
objectclass: account
objectclass: posixAccount
objectclass: shadowAccount
cn: dummy_admin
uid: dummy_admin
uidNumber: 1010
gidNumber: 1010
homeDirectory: /home/dummy_admin
loginShell: /bin/bash
gecos: dummy_admin
userPassword: {crypt}x
shadowLastChange: 0
shadowMax: 0
shadowWarning: 0" > $ACTION_FILE
ldapadd_macro
ldappasswd -x -H ldap://ldap -D "cn=admin,dc=example,dc=org" -w admin "uid=dummy_admin,dc=example,dc=org" -s adminadmin

# Create user groups
echo "Creating groups branch.."

cat >$ACTION_FILE <<EOF
dn: ou=groups,dc=example,dc=org
ou: groups
description: generic groups branch
objectclass: top
objectclass:organizationalunit
EOF
ldapadd_macro

echo Creating groups...
for i in 1 2; do
  cat <<EOG
dn: cn=group$i,ou=groups,dc=example,dc=org
objectClass: top
objectClass: posixGroup
gidNumber: 300$i

EOG
done > $ACTION_FILE
ldapadd_macro

for i in $USER_Ns; do
  if [ $i -eq 0 -o $i -eq 9 ]; then
    GROUPS="1 2"
  elif [ $i -lt 5 ]; then
    GROUPS="1"
  else
    GROUPS="2"
  fi
  for g in $GROUPS; do
    cat <<EOM
dn: cn=group$g,ou=groups,dc=example,dc=org
changetype: modify
add: memberuid
memberuid: user$i

EOM
  done
done >$ACTION_FILE
ldapmodify -x -H ldap://ldap -D "cn=admin,dc=example,dc=org" -w admin -f $ACTION_FILE

# Clean up
rm -f $ACTION_FILE

# Removing the lock for EOS-Storage
echo "Unlocking eos-controller for EOS-Storage deployment."
rm /tmp/SWAN-in-Docker/eos-storage-lock
echo "I'm done. Exiting..."


