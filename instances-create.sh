#!/bin/bash

set -e

[ "$DEFAULTS_LOADED" = "" ] && source defaults.sh

USAGE="Usage: instances-create.sh [project] [environment] [service] [vpc-id] [security-group-ids] [subnet-id] [elb-name] [ec2-instance-type] [ec2-ami] [extra-args]"

if [ "$#" -lt 6 ]; then
  echo "$USAGE"
  exit 1
fi

PROJECT=$1
ENVIRONMENT=$2
SERVICE=$3
VPC_ID=$4
SECURITY_GROUP_IDS=$5
SUBNET_ID=$6
ELB_NAME=$7
EC2_INSTANCE_TYPE=$8
EC2_AMI=$9
EXTRA_ARGS=${10}

[ "$EC2_INSTANCE_TYPE" = "" ] && EC2_INSTANCE_TYPE="${EC2_INSTANCE_TYPE_DEFAULT}"
[ "$EC2_AMI" = "" ] && EC2_AMI="${EC2_AMI_DEFAULT}"

KEY_NAME="$PROJECT"
USER_DATA="file://$(./userdata-create.sh $PROJECT $ENVIRONMENT $SERVICE)"

RUN_INSTANCES_RESULT=$(aws ec2 run-instances --image-id $EC2_AMI --count 1 --user-data $USER_DATA --instance-type $EC2_INSTANCE_TYPE --key-name $KEY_NAME --security-group-ids $SECURITY_GROUP_IDS --subnet-id $SUBNET_ID $EXTRA_ARGS)

INSTANCE_ID=$(echo "$RUN_INSTANCES_RESULT" | grep InstanceId | cut -d':' -f2 | cut -d'"' -f2)

RETVAL=-1
while [ $RETVAL -ne 0 ]; do
  sleep $EC2_CREATE_RESOURCE_SLEEP_DEFAULT
  (aws ec2 describe-instances --instance-ids $INSTANCE_ID >/dev/null || true)
  RETVAL=$?
done

while [ "$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --output text | grep STATE | grep -v STATEREASON | cut -f3)" = "pending" ]; do
  sleep $EC2_CREATE_RESOURCE_SLEEP_DEFAULT
done

echo -e "aws_InstanceId:\t$INSTANCE_ID"

aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Project,Value=$PROJECT Key=Environment,Value=$ENVIRONMENT Key=Service,Value=$SERVICE Key=Name,Value=$PROJECT-$ENVIRONMENT-$SERVICE >/dev/null

[ "$ELB_NAME" != "" ] && aws elb register-instances-with-load-balancer --load-balancer-name $ELB_NAME --instances $INSTANCE_ID >/dev/null

exit 0
