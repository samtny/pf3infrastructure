#!/bin/bash

set -e

[ "$DEFAULTS_LOADED" = "" ] && source defaults.sh

USAGE="Usage: ips-get.sh [project] [environment] [service] [subnet-ids]"

if [ $# -lt 1 ]; then
  echo "$USAGE"
  exit 1
fi

PROJECT=$1
ENVIRONMENT=$2
SERVICE=$3
SUBNET_IDS=$4

[ "$SERVICE" = "nat" ] && ENVIRONMENT="any"

FILTERS="Name=tag:Project,Values=$PROJECT"
[ "$ENVIRONMENT" != "" ] && FILTERS="$FILTERS Name=tag:Environment,Values=$ENVIRONMENT"
[ "$SERVICE" != "" ] && FILTERS="$FILTERS Name=tag:Service,Values=$SERVICE"

[ "$SUBNET_IDS" != "" ] && FILTERS="$FILTERS Name=subnet-id,Values=$SUBNET_IDS"

IP_ADDRESSES=$(aws ec2 describe-instances --query 'Reservations[].Instances[].[PrivateIpAddress]' --output text --filters $FILTERS | uniq)

echo "$IP_ADDRESSES"

exit 0
