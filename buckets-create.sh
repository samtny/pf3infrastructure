#!/bin/bash

set -e

USAGE="Usage: buckets-create.sh [project] [environment] [service] [control-email]"

if [ $# -ne 4 ]; then
  echo "$USAGE"
  exit 1
fi

PROJECT=$1
ENVIRONMENT=$2
SERVICE=$3
CONTROL_EMAIL=$4

aws s3api create-bucket --bucket ${PROJECT}-${ENVIRONMENT}-${SERVICE} --grant-full-control "emailaddress=\"$CONTROL_EMAIL\"" >/dev/null

echo -e "aws_BucketName:\t$PROJECT-$ENVIRONMENT-$SERVICE"

exit 0
