#!/usr/bin/env bash
# Make changes to files based on Environment Variables.

VERSION=1.0.0

# A file used to determine if/when this program has previously run.

SENTINEL_FILE=${SENZING_ROOT}/docker-runs.sentinel

# Return codes

OK=0
NOT_OK=1

# Short-circuit for certain commandline options.

if [ "$1" == "--version" ]; then
  echo "docker-entrypoint.sh version ${VERSION}"
  exit ${OK}
fi

if [ "$1" == "--sleep" ]; then
  echo "Sleeping"
  sleep 1d
  exit ${OK}
fi

# Make modifications based on SENZING_DATABASE_URL value.

if [ -z "${SENZING_DATABASE_URL}" ]; then
  echo "Using internal database"
else

  # Parse the SENZING_DATABASE_URL.

  PROTOCOL="$(echo ${SENZING_DATABASE_URL} | sed -e's,^\(.*\)://.*,\1,g')"
  DRIVER="$(echo ${SENZING_DATABASE_URL} | cut -d ':' -f1)"
  UPPERCASE_DRIVER=$(echo "${DRIVER}" | tr '[:lower:]' '[:upper:]')
  USERNAME="$(echo ${SENZING_DATABASE_URL} | cut -d '/' -f3 | cut -d ':' -f1)"
  PASSWORD="$(echo ${SENZING_DATABASE_URL} | cut -d ':' -f3 | cut -d '@' -f1)"
  HOST="$(echo ${SENZING_DATABASE_URL} | cut -d '@' -f2 | cut -d ':' -f1)"
  PORT="$(echo ${SENZING_DATABASE_URL} | cut -d ':' -f4 | cut -d '/' -f1)"
  SCHEMA="$(echo ${SENZING_DATABASE_URL} | cut -d '/' -f4)"

  # Construct Senzing version of database URL.
  
  NEW_SENZING_DATABASE_URL=""
  if [ "${PROTOCOL}" == "mysql" ]; then
    NEW_SENZING_DATABASE_URL="${PROTOCOL}://${USERNAME}:${PASSWORD}@${HOST}:${PORT}/?schema=${SCHEMA}"
  fi

  # Modify files in docker's Union File System.

  sed -i.$(date +%s) \
    -e "s/{SCHEMA}/${SCHEMA}/" \
    -e "s/{DRIVER}/${UPPERCASE_DRIVER}/" \
    -e "s/{HOST}/${HOST}/" \
    -e "s/{PORT}/${PORT}/" \
    -e "s/{SCHEMA}/${SCHEMA}/" \
    /etc/odbc.ini

  # Modify files in mounted volume, if needed.  The "sentinel file" is created after first run.

  if [ ! -f ${SENTINEL_FILE} ]; then

    sed -i.$(date +%s) \
      -e "s|G2Connection=sqlite3://na:na@${SENZING_ROOT}/g2/sqldb/G2C.db|G2Connection=${NEW_SENZING_DATABASE_URL}|" \
      ${SENZING_ROOT}/g2/python/G2Project.ini

    sed -i.$(date +%s) \
      -e "s|CONNECTION=sqlite3://na:na@${SENZING_ROOT}/g2/sqldb/G2C.db|CONNECTION=${NEW_SENZING_DATABASE_URL}|" \
      ${SENZING_ROOT}/g2/python/G2Module.ini

  fi
fi

# Work-around https://senzing.zendesk.com/hc/en-us/articles/360009212393-MySQL-V8-0-ODBC-client-alongside-V5-x-Server

if [ ! -f ${SENZING_ROOT}/g2/lib/centos/libmysqlclient.so.21 ]; then
  mkdir -p ${SENZING_ROOT}/g2/lib/centos
  cp /usr/lib64/mysql/libmysqlclient.so.21 ${SENZING_ROOT}/g2/lib/centos
fi

# Append to a "sentinel file" to indicate when this script has been run.
# The sentinel file is used to identify the first run from subsequent runs for "first-time" processing.

echo "$(date)" >> ${SENTINEL_FILE}

# Run the command specified by the parameters.

exec $@
