
echo setting up the tests...  'logfile: # less test-setup.log'

{
    set -o verbose
    docker build -t microtests -f microtests.Dockerfile .
    docker rm -f microtests
    docker run -d -it --name microtests --network demonet microtests
    set +o verbose
} > test-setup.log 2>&1

echo
echo running all tests...   'logfile: # docker exec -it microtests less /microtests.d/test.log'
echo 

docker exec -it microtests bash /microtests.d/run_all_tests.sh




