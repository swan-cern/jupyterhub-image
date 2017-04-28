#######
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT=`basename "${BASH_SOURCE[0]}"`
#######

function runtest {
    "$@" >> test.log 2>&1 
    local status=$?
    if [ $status -ne 0 ]; then
        echo "ERROR running test $1 (exit code $status)" >&2
    else
	echo "OK" >&2
    fi
    return $status
}


cd $DIR

echo > test.log

for test in test_*.sh; do
    echo running $test >&2 
    echo running $test >> test.log
    runtest ./$test || exit 1
done

echo "All tests passed successfully" >&2 

