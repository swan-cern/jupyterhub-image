## How to build MySQL Docker image for CERNBox

These instructions describe how to build the Docker image for MySQL (MariaDB) server to be used as database backend for CERNBox.
The procedure is completely automated, but manual steps for verification are still required.


### Context 
CERNBox can be used either with a SQLite or with a MySQL database backend. 
  * SQLite is the default solution, with the database being colocated in the same container of the CERNBox service.
  * MySQL is the preferred solution production deployments. If MySQL is the choice, another container running the database server must be provided and executed.


### The problem
CERNBox populates the database with custom tables at schemas during the installation step, which takes place when building the CERNBox Docker image.
In order to support diverse deployment scenarios, the choice of the database backend for CERNBox is instead deferred to the run phase.
Being SQLite the default choice, the SQLite database is initialized when installing CERNBox but no action is taken with the MySQL databse.


### The solution
The Docker image for the MySQL server must already have on-board a pre-initialized database with tables and schemas required by CERNBox.
To achieve this, #TODO#


### How to build the MySQL Docker image
Simply run the `initMySQL.sh` script.


### How it works
The script invokes docker-compose, which starts a container with MySQL server (mariadb:5.5) and a container with base CERN CentOS 7 (cern/cc7-base:20170922).
On the latter, a valilla CERNBox installation will take place and populate the MySQL database with the required tables and schemas.
At the end of the process, the populated database files will be compressed into `MySQL.tar.gz` and stored on the host machine. Right after, the container with CERNBox and MySQL will be torn down.
The entire setup should take about two minutes with a good Internet connection.


### What to do next
The content of file `MySQL.tar.gz` should than be copied in `/var/lib/mysql` on the Docker container running the MySQL server for CERNBox.
MySQL will then be ready to accept requests from CERNBox out-of-the-box, without requiring any further configuration.


### Requirements
  * Internet connection
  * Docker
  * Docker-compose
  * tar

