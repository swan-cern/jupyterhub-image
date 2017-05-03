#!/bin/bash

#RUN_IN_CONTAINER cvmfs

set -o errexit # bail out on all errors immediately
set -x

CVMFS_ENDPOINTS=""
CVMFS_TEST="/cvmfs/sft.cern.ch/lcg/views/LCG_88/x86_64-slc6-gcc49-opt/setup.sh"
CVMFS_PING=$OUTPUT_DIR"/cvmfs_ping.log"

# Ping CVMFS repository
CVMFS_ENDPOINTS=`cat /etc/cvmfs/default.local | grep CVMFS_HTTP_PROXY | cut -d '=' -f 2 | cut -d '|' -f 1 | sed 's/http:\/\///g' | sed 's/:3128//g' | tr -d "'" | tr ';' ' '`
for i in $CVMFS_ENDPOINTS ;
do
	ping -c 10 -i 0.5 -w 10 $i || exit 1
done

# Probe CVMFS endpoint
cvmfs_config probe || exit 1

# Try to read a file (same path of software for Jupyter Notebooks)
cat $CVMFS_TEST > /dev/null || exit 1

