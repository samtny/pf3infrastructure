#!/bin/bash

set -e

[ "$DEFAULTS_LOADED" = "" ] && source defaults.sh

USAGE="Usage: eips-get.sh [project] [environment] [service]"

if [ $# -lt 1 ]; then
  echo "$USAGE"
  exit 1
fi

PROJECT=$1
ENVIRONMENT=$2
SERVICE=$3

[ "$SERVICE" = "nat" ] && ENVIRONMENT="any"

FILTERS="Name=tag:Project,Values=$PROJECT"
[ "$ENVIRONMENT" != "" ] && FILTERS="$FILTERS Name=tag:Environment,Values=$ENVIRONMENT"
[ "$SERVICE" != "" ] && FILTERS="$FILTERS Name=tag:Service,Values=$SERVICE"

DESCRIBE_INSTANCES=$(aws ec2 describe-instances --output text --filters $FILTERS)

ASSOCIATIONS=$(echo "$DESCRIBE_INSTANCES" | grep "^ASSOCIATION")

if [ "$ASSOCIATIONS" != "" ]; then
  EIPS=$(echo "$ASSOCIATIONS" | cut -f4 | uniq)
fi

echo "$EIPS"

exit 0
