#!/bin/bash

set -e

[ "$DEFAULTS_LOADED" = "" ] && source defaults.sh

USAGE="Usage: elbs-create.sh [project] [environment] [service] [subnet-ids] [security-group-ids] [vpc-id] [target-ids]"

if [ "$#" -ne 7 ]; then
  echo "$USAGE"
  exit 1
fi

PROJECT=$1
ENVIRONMENT=$2
SERVICE=$3
SUBNET_IDS=$4
SECURITY_GROUP_IDS=$5
VPC_ID=$6
TARGET_IDS=$7

ELB_NAME="$PROJECT-$ENVIRONMENT-$SERVICE"
TARGET_GROUP_NAME="$PROJECT-$ENVIRONMENT-$SERVICE"
SSL_CERTIFICATE_ID=""

HTTP_LISTENER="Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80"
HTTPS_LISTENER="Protocol=HTTPS,LoadBalancerPort=443,InstanceProtocol=HTTP,InstancePort=443"
LISTENERS=$(echo $HTTP_LISTENER $HTTPS_LISTENER)

TAGS="'Key=Project,Value=$PROJECT Key=Environment,Value=$ENVIRONMENT Key=Service,Value=$SERVICE'"

HEALTH_CHECK="Target=TCP:80,Timeout=5,Interval=10,UnhealthyThreshold=2,HealthyThreshold=2"

#aws elb create-load-balancer --load-balancer-name $ELB_NAME --listeners $LISTENERS --subnets $SUBNET_IDS --security-groups $SECURITY_GROUP_IDS >/dev/null
aws elbv2 create-load-balancer --name $ELB_NAME --subnets $SUBNET_IDS --security-groups $SECURITY_GROUP_IDS >/dev/null

ELB_ARN="$(aws elbv2 describe-load-balancers --names $ELB_NAME --output text | grep LoadBalancerArn | cut -f3)"

aws elbv2 create-target-group --name ${TARGET_GROUP_NAME} --protocol HTTP --port 80 --vpc-id ${VPC_ID}

TARGET_GROUP_ARN="$(aws elbv2 describe-target-groups --names $TARGET_GROUP_NAME --output text | grep TargetGroupArn | cut -f3)"

aws elbv2 register-targets --target-group-arn targetgroup-arn --targets Id=i-12345678 Id=i-23456789

#aws elb configure-health-check --load-balancer-name $ELB_NAME --health-check $HEALTH_CHECK >/dev/null

echo -e "aws_ElbName:\t$ELB_NAME"

exit 0
