#!/bin/bash

set -e

[ "$DEFAULTS_LOADED" = "" ] && source defaults.sh

USAGE="Usage: elbs-create.sh [project] [environment] [service] [subnet-ids] [security-group-ids] [target-group-arn]"

if [ "$#" -ne 6 ]; then
  echo "$USAGE"
  exit 1
fi

PROJECT=$1
ENVIRONMENT=$2
SERVICE=$3
SUBNET_IDS=$4
SECURITY_GROUP_IDS=$5
TARGET_GROUP_ARN=$6

ELB_NAME="$PROJECT-$ENVIRONMENT-$SERVICE"

TAGS="Key=Project,Value=$PROJECT Key=Environment,Value=$ENVIRONMENT Key=Service,Value=$SERVICE"

aws elbv2 create-load-balancer --name ${ELB_NAME} --subnets ${SUBNET_IDS} --security-groups ${SECURITY_GROUP_IDS} --tags ${TAGS} >/dev/null

ELB_ARN="$(aws elbv2 describe-load-balancers --names ${ELB_NAME} --output text | grep LOADBALANCERS | cut -f6)"

aws elbv2 create-listener --load-balancer-arn ${ELB_ARN} --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=${TARGET_GROUP_ARN}
#aws elbv2 create-listener --load-balancer-arn ${ELB_ARN} --protocol HTTPS --port 443 --default-actions Type=forward,TargetGroupArn=${TARGET_GROUP_ARN}

echo -e "aws_ElbName:\t$ELB_NAME"

exit 0
