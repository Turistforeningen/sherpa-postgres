#!/bin/bash
source /secrets/aws.env

HOST=$1
if [ -z "${HOST}" ]; then
  echo "usage: $0 <postgres hostname> [backup file]"
  exit 1
fi

PSQL="gosu postgres psql -h ${HOST}"
PGDIR=/usr/share/postgresql/$PG_MAJOR/contrib/postgis-$POSTGIS_MAJOR

s3_path="s3://${AWS_S3_BUCKET_NAME}${AWS_S3_BUCKET_PATH}"
s3_file=$2
# Default to the latest backup if no argument specified
: ${s3_file:=`aws s3 ls ${s3_path} | tail -n 1 | awk ' {print $4}'`}

echo "Downloading '${s3_file}' from S3..."
aws s3 cp "${s3_path}${s3_file}" sherpa.xz
AWS_STATUS=$?
if [ $AWS_STATUS -ne 0 ]; then
  echo "AWS CLI exited with code $AWS_STATUS; aborting import"
  exit 1
fi

xz --decompress sherpa.xz

$PSQL -e <<EOSQL
DROP DATABASE IF EXISTS sherpa;
CREATE DATABASE sherpa template template_postgis
  lc_collate 'nb_NO.utf8'
  lc_ctype 'nb_NO.utf8';
EOSQL

echo "Restoring database..."
${PGDIR}/postgis_restore.pl sherpa | ${PSQL} -e sherpa
