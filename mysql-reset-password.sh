#!/bin/bash

#############################################
## Reset MySQL root password and auth plugin
#############################################

# Stop MySQL service
service mysql stop
# Show MySQL service satus
service mysql status | grep "Active:.*)"
# Find process MySQL
ps -eaf | grep [m]ysql
# Make dir and set rights for prevent execution error
mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld

# root username
MYSQLUSER="root"
# New password
MYSQLNEWPASS="qwerty"
# Set PID file
MYSQLRECOVERYPID="/var/run/mysqld/mysqld.pid"
# Path to mysqld.sock
MYSQLSOCKET="/var/run/mysqld/mysqld.sock"
# "auth_socket" or "mysql_native_password"
MYSQLPLUGIN="mysql_native_password"
# Number of attempts
STOPCKECKINGTRY=10
# Set the initial counter
STOPCKECKINGCOUNT=0
# Set timeout for restart service
MYSQLTIMEOUT=1

# Start MySQL in unsafe mode
mysqld --defaults-file=<(echo -e "[mysqld] \
        \nuser=root \
        \nskip-grant-tables \
        \nskip-networking \
        \nexplicit_defaults_for_timestamp=true \
        \npid-file=$MYSQLRECOVERYPID \
        \nsocket=${MYSQLSOCKET}") \
        &> /dev/null &

# Waiting for MySQL to start
until $(mysql -e "STATUS;" &> /dev/null); do 
        echo -e " Waiting for MySQL to start - ${STOPCKECKINGCOUNT}/${STOPCKECKINGTRY}"
        sleep ${MYSQLTIMEOUT}
        ((STOPCKECKINGCOUNT++))
        if [ ${STOPCKECKINGCOUNT} -ge ${STOPCKECKINGTRY} ]; then 
                echo -e "\e[33m Time is over.\n Maybe MySQL not running \e[39m"
                STOPSCRIPT=true
                break
        fi
done

# Set new pass if MySQL is running
if [ ${STOPSCRIPT} ]; then
        exit 1
else
        mysql -e "SELECT user,authentication_string,plugin,host FROM mysql.user WHERE user='root'; UPDATE mysql.user SET plugin = \"${MYSQLPLUGIN}\" WHERE user='root'; UPDATE mysql.user SET authentication_string=PASSWORD(\"${MYSQLNEWPASS}\") WHERE user='root'; FLUSH PRIVILEGES; SHUTDOWN;"
fi

# Waiting $MYSQLTIMEOUT seccond for stop MySQL service
sleep ${MYSQLTIMEOUT}

# Kill MySQL process if not finished in time
if [ -d $MYSQLRECOVERYPID ]; then 
        kill echo $(cat $MYSQLRECOVERYPID)
fi

# Start MySQL service in normal mode
service mysql start

# Get root authentication_string for check
mysql   -u ${MYSQLUSER} \
        --password="${MYSQLNEWPASS}" \
        --execute="SELECT user,authentication_string,plugin,host FROM mysql.user WHERE user='root';" \
        2>/dev/null

# Check MySQL run simple command
if [ $? -eq 0 ]; then
        mysql -e "STATUS;" \
        -u ${MYSQLUSER} \
        -p${MYSQLNEWPASS}
        echo -e "\n\e[32m Password has been changed \e[39m\n\n"
        # sleep ${MYSQLTIMEOUT}
        # exit 0
else
       echo -e "\n\e[33m Fail check MySQL status \e[39m\n"
       exit 1
fi
