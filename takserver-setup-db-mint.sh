#!/bin/bash

# Script to set up the TAKServer database.
# This is meant to be run as root.
# Since it asks the user for confirmation before obliterating his database,
# it cannot be run by the RPM installer and must be a manual post-install step.
#
# Usage: takserver-db-setup.sh [db-name]
#

#if [ "$EUID" -ne 0 ]
#  then echo "$0 must be run as root."
#  exit 1
#fi

# switch CWD to the location where this script resides
cd `dirname $0`

DB_NAME=$1
if [ $# -lt 1 ]; then
  DB_NAME=cot
fi

# Figure out where the system keeps the PostgreSQL configuration files

if [ -z ${PGDATA+x} ]; then
   if [ -d /etc/postgresql/12/main ]; then
        export PGDATA=/etc/postgresql/12/main
        POSTGRES_CMD="/bin/systemctl restart postgresql.service"
   else
       echo "PGDATA not set and unable to find PostgreSQL data directory automatically."
       echo "Please set PGDATA and re-run this script."
       exit 1
   fi
fi

if [ ! -d $PGDATA ]; then
  echo "ERROR: Cannot find PostgreSQL config directory. Please set PGDATA manually and re-run."
  exit 1
fi

# Get user's permission before obliterating the database
DB_EXISTS=`su postgres -c "psql -l 2>/dev/null" | grep ^[[:blank:]]*$DB_NAME`
if [ "x$DB_EXISTS" != "x" ]; then
   echo "WARNING: Database '$DB_NAME' already exists!"
   echo "Proceeding will DESTROY your existing data!"
   echo "You can back up your data using the pg_dump command. (See 'man pg_dump' for details.)"
   read -p "Type 'erase' (without quotes) to erase the '$DB_NAME' database now:" kickme
   if [ "$kickme" != "erase" ]; then
       echo "User didn't say 'erase'. Aborting."
       exit 1
   fi
   su postgres -c "psql --command='drop database if exists $DB_NAME;'"
fi 

# Install our version of pg_hba.conf
echo "Installing TAKServer's version of PostgreSQL access-control policy."
# Back up pg_hba.conf
BACKUP_SUFFIX=`date --rfc-3339='seconds' | sed 's/ /-/'`
HBA_BACKUP=$PGDATA/pg_hba.conf.backup-$BACKUP_SUFFIX
if [ -e /opt/tak/db-utils/pg_hba.conf ] || [ -e pg_hba.conf ]; then
  if [ -e $PGDATA/pg_hba.conf ]; then
    mv $PGDATA/pg_hba.conf $HBA_BACKUP
    echo "Copied existing PostgreSQL access-control policy to $HBA_BACKUP."
  fi
# copy the tak server file into it's place
  cp /opt/tak/db-utils/pg_hba.conf $PGDATA
  chown postgres:postgres $PGDATA/pg_hba.conf
  chmod 600 $PGDATA/pg_hba.conf
  echo "Installed TAKServer's PostgreSQL access-control policy to $PGDATA/pg_hba.conf."
  echo "Restarting PostgreSQL service."
  $POSTGRES_CMD
else
  echo "ERROR: Unable to find pg_hba.conf!"
  exit 1
fi

CONF_BACKUP=$PGDATA/postgresql.conf.backup-$BACKUP_SUFFIX
if [ -e /opt/tak/db-utils/postgresql.conf ] || [ -e postgresql.conf ];  then
  if [ -e $PGDATA/postgresql.conf ]; then
    mv $PGDATA/postgresql.conf $CONF_BACKUP
    echo "Copied existing PostgreSQL configuration to $CONF_BACKUP."
  fi
# copy the tak server file into it's place
  cp /opt/tak/db-utils/postgresql.conf $PGDATA
  chown postgres:postgres $PGDATA/postgresql.conf
  chmod 600 $PGDATA/postgresql.conf
  echo "Installed TAKServer's PostgreSQL configuration to $PGDATA/postgresql.conf."
  echo "Restarting PostgreSQL service."
  $POSTGRES_CMD
fi

DB_NAME=cot
if [ $# -eq 1 ] ; then
    DB_NAME=$1
fi

# Create the user "martiuser" if it does not exist.
echo "Creating user \"martiuser\" ..."
su - postgres -c "psql -U postgres -c \"CREATE ROLE martiuser LOGIN ENCRYPTED PASSWORD 'md564d5850dcafc6b4ddd03040ad1260bc2' SUPERUSER INHERIT CREATEDB NOCREATEROLE;\""

# create the database
echo "Creating database $DB_NAME"
su - postgres -c "createdb -U postgres --owner=martiuser $DB_NAME"
if [ $? -ne 0 ]; then
    exit 1
fi

echo "Database $DB_NAME created."

if [ IS_DOCKER ]; then
   java -jar SchemaManager.jar upgrade
elif [ -e /opt/tak/db-utils/SchemaManager.jar ]; then
   java -jar /opt/tak/db-utils/SchemaManager.jar upgrade
else
   echo "ERROR: Unable to find SchemaManager.jar!"
   exit 1
fi

echo "Database updated with SchemaManager.jar"

if [ ! -x /usr/bin/systemctl ]; then
  echo "Systemctl was not found. Skipping Systemd configuration."
  exit 1
fi

# Set PostgreSQL to run automatically at boot time
if [ -d /var/lib/pgsql/10/data ]; then
    START_INIT="chkconfig --level 345 postgresql-10 on"
elif [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl enable postgresql.service
elif [ -d /var/lib/pgsql/9.4/data ]; then
    START_INIT="chkconfig --level 345 postgresql-9.4 on"
elif [ -d /var/lib/pgsql/9.5/data ]; then
    START_INIT="chkconfig --level 345 postgresql-9.5 on"
elif [ -d /var/lib/pgsql/9.6/data ]; then
    START_INIT="chkconfig --level 345 postgresql-9.6 on"
else
  echo "ERROR: unable to detect postgres version to start on boot"
  exit 1
fi
    
$START_INIT
echo "set postgres to start on boot"


