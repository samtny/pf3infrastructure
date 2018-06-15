#!/bin/bash

set -e

[ "$DEFAULTS_LOADED" = "" ] && source defaults.sh

USAGE="Usage: target-groups-create.sh [project] [environment] [service] [vpc-id] [target-ids]"

if [ "$#" -ne 5 ]; then
  echo "$USAGE"
  exit 1
fi

PROJECT=$1
ENVIRONMENT=$2
SERVICE=$3
VPC_ID=$4
TARGET_IDS=$5

TARGET_GROUP_NAME="$PROJECT-$ENVIRONMENT-$SERVICE"

aws elbv2 create-target-group --name ${TARGET_GROUP_NAME} --protocol HTTP --port 80 --vpc-id ${VPC_ID} --health-check-protocol HTTP --health-check-port 80 --health-check-interval-seconds 10 --health-check-timeout-seconds 5 --healthy-threshold-count 2 --unhealthy-threshold-count 2

TARGET_GROUP_ARN="$(aws elbv2 describe-target-groups --names ${TARGET_GROUP_NAME} --output text | grep TARGETGROUPS | cut -f10)"

echo -e "aws_TargetGroupArn:\t${TARGET_GROUP_ARN}"

[ "$TARGET_IDS" != "" ] && aws elbv2 register-targets --target-group-arn ${TARGET_GROUP_ARN} --targets Id=${TARGET_IDS}

echo -e "aws_TargetGroupName:\t${TARGET_GROUP_NAME}"

exit 0
