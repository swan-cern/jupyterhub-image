#!/bin/bash

#
# Run command from the host:
#docker build -t microtests -f microtests.Dockerfile .; docker run --net demonet --name mt --rm --volume /var/run/docker.sock:/var/run/docker.sock:rw -it microtests
#
# TODO: include in Docker Compose
#		Also set the related lock to wait for all the other services to be there
#

# These should be move to ENV variables in the docker compose
RUNNING_CONTAINERS="cernbox cernboxgateway cvmfs eos-fst1 eos-fst2 eos-fst3 eos-fst4 eos-fst5 eos-fst6 eos-fuse eos-mgm eos-mq jupyterhub openldap" 
SERVICE_CONTAINERS="eos-controller openldap-ldapadd"
LDAP_CLIENTS="cernbox eos-fuse eos-mgm eos-mq jupyterhub"

OUTPUT_DIR="/tests_results"
NET_OUT=$OUTPUT_DIR"/netscan.log"
PORT_OUT=$OUTPUT_DIR"/portscan.log"
LDAP_OUT=$OUTPUT_DIR"/ldap.log"
LDAPS_OUT=$OUTPUT_DIR"/ldaps.log"
PAM_OUT=$OUTPUT_DIR"/pam.log"

CVMFS_ENDPOINTS=""
CVMFS_TEST="/cvmfs/sft.cern.ch/lcg/views/LCG_88/x86_64-slc6-gcc49-opt/setup.sh"
CVMFS_PING=$OUTPUT_DIR"/cvmfs_ping.log"

JH_IMLIST=$OUTPUT_DIR"/jupyterhub_imagelist.log"
JH_USERIMAGE="cernphsft/systemuser"
JH_USERIMAGE_VER="v2.9"

mkdir -p $OUTPUT_DIR


# ----- Basic reachability test with ping
echo ""
echo "Checking network connectivity..."
echo "#hostname result exit_code verbose_output" >> $NET_OUT
for i in $RUNNING_CONTAINERS $SERVICE_CONTAINERS;
do
	ping -c 1 -w 5 $i > $NET_OUT.$i 2>&1 
	if [ "$?" == "0" ]; then
		RES="Success"
		MEAN=`cat $NET_OUT.$i | grep "rtt min/avg/max/mdev" | cut -d = -f 2 | cut -d / -f 2`
		echo "ping $i... OK ($MEAN ms)"
	else
		RES="Failure"
		echo "ping $i... Fail"
		echo "WARNING: Unable to reach $i."
	fi
	echo "$i $RES $EXIT $NET_OUT.$i" >> $NET_OUT
done


# ----- Checking open ports with nmap
echo ""
echo "Checking open TCP ports on containers..."
echo "#hostname open_ports exit_code verbose_output" >> $PORT_OUT
for i in $RUNNING_CONTAINERS $SERVICE_CONTAINERS;
do
	nmap -PS --max-retries 0 --host-timeout 10s - $i > $PORT_OUT.$i 2>&1 
	EXIT=`echo $?`
	PORTS=`cat $PORT_OUT.$i | tr -s " " | grep "/tcp open" | cut -d " " -f 1 | tr "\n" ","`
	if [ -z "$PORTS" ]; then
		PORTS="--"
	fi 
	echo "nmap $i... Open ports: $PORTS"
	echo "$i $PORTS $EXIT $PORT_OUT.$i" >> $PORT_OUT
done


# ----- Query LDAP server and contrast obtained results
echo ""
echo "Checking LDAP..."
# --> From LDAP itself (check you have some users and generate groundtruth)
docker exec openldap ldapsearch -x -H ldap://localhost -b dc=example,dc=org -D "cn=admin,dc=example,dc=org" -w admin > $LDAP_OUT
docker exec openldap ldapsearch -x -H ldaps://localhost -b dc=example,dc=org -D "cn=admin,dc=example,dc=org" -w admin > $LDAPS_OUT
# --> From other containers
for i in $LDAP_CLIENTS;
do
	docker exec $i ldapsearch -x -H ldap://ldap -b dc=example,dc=org -D "cn=admin,dc=example,dc=org" -w admin > $LDAP_OUT.$i
	DIFF=`diff $LDAP_OUT $LDAP_OUT.$i`
	if [ -z "$DIFF" ]; then
		echo $i... OK
	else
		echo $i... Fail
		echo "WARNING: LDAP configuration for $i is inconsistent."
	fi
done

# ----- Check to be able to retrieve account info via NSS/PAM
echo ""
echo "Checking NSS/PAM..."
for i in $LDAP_CLIENTS;
do
	errors=0
	USERLIST=`cat $LDAP_OUT.$i | grep uid: | cut -d ' ' -f 2 | tr '\n' ' ' | head -n 10`
	for un in $USERLIST;
	do
		docker exec $i id $un >> $PAM_OUT.$i 2>&1
		errors=$((errors + $?))
	done
	if [ "$errors" == "0" ]; then
		echo $i... OK
	else
		echo $i... Fail
		echo "WARNING: NSS/PAM configuration for $i is inconsistent."
	fi
done



# ----- Tests on CVMFS
echo ""
echo "Checking CVMFS reachability..."

# Ping CVMFS repository
CVMFS_ENDPOINTS=`docker exec cvmfs cat /etc/cvmfs/default.local | grep CVMFS_HTTP_PROXY | cut -d '=' -f 2 | cut -d '|' -f 1 | sed 's/http:\/\///g' | sed 's/:3128//g' | tr -d "'" | tr ';' ' '`
for i in $CVMFS_ENDPOINTS this.is.a.fake.endpoit.and.should.fail;
do
	ping -c 10 -i 0.5 -w 10 $i > $CVMFS_PING.$i 2>&1
	if [ "$?" == "0" ]; then
		MEAN=`cat $CVMFS_PING.$i | grep "rtt min/avg/max/mdev" | cut -d = -f 2 | cut -d / -f 2`
		echo "ping $i... OK ($MEAN ms)"
	else
		echo "ping $i... Fail"
		echo "WARNING: Unable to reach $i."
	fi
done

# Probe CVMFS endpoint
docker exec cvmfs cvmfs_config probe

# Try to read a file (same path of software for Jupyter Notebooks)
docker exec cvmfs cat $CVMFS_TEST > /dev/null
if [ "$?" == "0" ]; then
	echo "Reading setup file from CVMFS... OK"
else
	echo "Reading setup file from CVMFS... Fail"
	echo "WARNING: Unable to read from CVMFS." 
fi


# ----- Tests on JupyterHub
echo ""
echo "Check Docker functionalities from JupyterHub..."
docker exec jupyterhub docker images > $JH_IMLIST 2>&1
if [ "$?" == "0" ]; then
	echo "Connect to Docker daemon on the host... OK"
	echo "Docker server version: "`docker version --format '{{.Server.Version}}'`
	echo "Docker client version: "`docker version --format '{{.Client.Version}}'`

	AVAILABLE_USERIMAGE=`grep -i $JH_USERIMAGE $JH_IMLIST | grep -i $JH_USERIMAGE_VER | tr -s ' ' | cut -d ' ' -f 1,2 | tr ' ' ':'`
	if [ "$JH_USERIMAGE:$JH_USERIMAGE_VER" == "$AVAILABLE_USERIMAGE" ]; then
		echo "Availabiliy of Single-User's Jupyter server image... OK"
		echo "Spawning user image... jupyter_test:" `docker exec jupyterhub docker run --name jupyter_test -it -d $AVAILABLE_USERIMAGE tail -f /dev/null`
		echo "Stopping:" `docker exec jupyterhub docker stop jupyter_test`
		echo "Removing:" `docker exec jupyterhub docker rm jupyter_test`
	else
		echo "Availabiliy of Single-User's Jupyter server image... Fail"
	fi

else
	echo "Connect to Docker daemon on the host... Fail"
	echo "WARNING: Unable to connect to Docker socket on the host."
	echo "WARNING: Unable to soawn Single-User's container."
fi


# ----- Tests on EOS


# ----- Tests on CERNBox web server


# ----- Test basic HTTP operations on the CERNBox gateway


export CERNBOXURL=https://cernboxgateway/cernbox/desktop/remote.php/webdav

dd if=/dev/zero of=/tmp/largefile1M.dat bs=1000 count=1000
dd if=/dev/zero of=/tmp/largefile10M.dat bs=100000 count=1000


FILES=/etc/passwd /tmp/largefile1M.dat /tmp/largefile10M.dat

# TODO: loop on FILES

# upload
curl -f -k -u user0:test0 --upload-file /etc/passwd ${CERNBOXURL}/home/passwd || exit 1

# overwrite file
curl -f -k -u user0:test0 --upload-file /etc/passwd ${CERNBOXURL}/home/passwd || exit 1

# download
curl -f -k -u user0:test0 ${CERNBOXURL}/home/passwd > /dev/null || exit 1


# test expected failures

curl -s -f -k -u user0:test1 --upload-file /etc/passwd ${CERNBOXURL}/home/passwd && echo "ERROR: PUT request should fail (wrong password) but succeeded" && exit 1

curl -s -f -k -u user0:test0 --upload-file /etc/passwd ${CERNBOXURL}/wronghome/passwd && echo "ERROR: PUT request should fail (wrong URI) but succeeded" && exit 1

curl -s -f -k -u user0:test0 ${CERNBOXURL}/home/passwd_does_not_exist_1234 > /dev/null && echo "ERROR: GET request should fail (no file on the server) but succeeded " && exit 1



