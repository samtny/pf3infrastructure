#!/bin/bash

set -e

[ "$DEFAULTS_LOADED" = "" ] && source defaults.sh

USAGE="Usage: gateways-create.sh [project] [vpc-id]"

if [ $# -ne 2 ]; then
  echo "$USAGE"
  exit 1
fi

PROJECT=$1
VPC_ID=$2

SLEEP_RESOURCE_CREATE=2

GATEWAY_ID=$(aws ec2 create-internet-gateway | grep InternetGatewayId | cut -d':' -f2 | cut -d'"' -f2)

RETVAL=-1
while [ $RETVAL -ne 0 ]; do
  sleep $SLEEP_RESOURCE_CREATE
  (aws ec2 describe-internet-gateways --internet-gateway-ids $GATEWAY_ID || true)
  RETVAL=$?
done

aws ec2 attach-internet-gateway --internet-gateway-id $GATEWAY_ID --vpc-id $VPC_ID >/dev/null 

aws ec2 create-tags --tags "Key=Project,Value=$PROJECT Key=Name,Value=$PROJECT" --resources $GATEWAY_ID >/dev/null

echo -e "aws_GatewayId:\t$GATEWAY_ID"

exit 0

