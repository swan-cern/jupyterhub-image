!/bin/bash
set -o errexit # bail out on all errors immediately

export CERNBOXURL=https://cernboxgateway/cernbox/desktop/remote.php/webdav

dd if=/dev/zero of=/tmp/largefile1M.dat bs=1000 count=1000
dd if=/dev/zero of=/tmp/largefile10M.dat bs=100000 count=1000


FILES="/etc/passwd /tmp/largefile1M.dat /tmp/largefile10M.dat"

echo $FILES

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

exit 0
