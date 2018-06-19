#!/bin/bash

set -e

# requirements;
# aws-cli v1.15
# curl
# aws account environment variables are set

[ "$DEFAULTS_LOADED" = "" ] && source defaults.sh

USAGE="Usage: environments-create.sh [project] [environment]"

if [ $# -ne 2 ]; then
  echo "$USAGE"
  exit 1
fi

PROJECT=$1
ENVIRONMENT=$2

SLEEP_NAT_PENDING=5
SLEEP_RDS_CREATING=5

# vpc

exec 5>&1
VPC_DATA=$(bash vpcs-get.sh ${PROJECT} | tee >(cat - >&5))

VPC_ID=$(echo "$VPC_DATA" | grep "aws_VpcId" | cut -f2)
SUBNET_ID_PRIVATE=$(echo "$VPC_DATA" | grep "aws_SubnetIdPrivate" | cut -f2)
SUBNET_ID_PUBLIC=$(echo "$VPC_DATA" | grep "aws_SubnetIdPublic" | cut -f2)
SUBNET_ID_PUBLIC_ALT=$(echo "$VPC_DATA" | grep "aws_SubnetIdPublicAlt" | cut -f2)
SECURITY_GROUP_ID_ELB=$(echo "$VPC_DATA" | grep "aws_SecurityGroupIdElb" | cut -f2)
SECURITY_GROUP_ID_LAMP=$(echo "$VPC_DATA" | grep "aws_SecurityGroupIdLamp" | cut -f2)

# s3 buckets

INSTANCE_PROFILE_NAME_LAMP=$(bash instance-profile-create.sh ${PROJECT} ${ENVIRONMENT} lamp | grep aws_InstanceProfileName | cut -f2)
echo -e "aws_InstanceProfileNameLamp:\t$INSTANCE_PROFILE_NAME_LAMP"

BUCKET_NAME_LAMP=$(bash buckets-create.sh ${PROJECT} ${ENVIRONMENT} lamp | grep aws_BucketName | cut -f2)
echo -e "aws_BucketNameLamp:\t$BUCKET_NAME_LAMP"

# instances

INSTANCE_ID_LAMP=$(bash instances-create.sh ${PROJECT} ${ENVIRONMENT} lamp ${VPC_ID} ${SECURITY_GROUP_ID_LAMP} ${SUBNET_ID_PRIVATE} "" ${EC2_INSTANCE_TYPE_LAMP} ${EC2_AMI_LAMP} '--block-device-mappings [{"DeviceName":"/dev/xvdf","Ebs":{"VolumeSize":80}}]' | grep "aws_InstanceId" | cut -f2)
echo -e "aws_InstanceIdLamp:\t$INSTANCE_ID_LAMP"

# elb target groups

TARGET_GROUP_ARN_LAMP=$(bash target-groups-create.sh ${PROJECT} ${ENVIRONMENT} lamp ${VPC_ID} ${INSTANCE_ID_LAMP} | grep "aws_TargetGroupArn" | cut -f2)
echo -e "aws_TargetGroupArnLamp:\t$TARGET_GROUP_ARN_LAMP"

# elbs

ELB_NAME_LAMP=$(bash elbs-create.sh ${PROJECT} ${ENVIRONMENT} lamp "${SUBNET_ID_PUBLIC_ALT} ${SUBNET_ID_PRIVATE}" ${SECURITY_GROUP_ID_ELB} ${TARGET_GROUP_ARN_LAMP} | grep "aws_ElbName" | cut -f2)
echo -e "aws_ElbNameLamp:\t$ELB_NAME_LAMP"

# wait for NAT

INSTANCE_ID_NAT=$(echo "$VPC_DATA" | grep "aws_InstanceIdNat" | cut -f2)

IP_ADDRESS_NAT=$(aws ec2 describe-instances --output text --filters Name=tag:Name,Values=${PROJECT}-any-nat | grep -m 1 "^ASSOCIATION" | cut -f4)
echo -e "aws_IpAddressNat:\t$IP_ADDRESS_NAT"

nc -w 1 -z ${IP_ADDRESS_NAT} 22 || true
RETVAL=$?
while [ ! ${RETVAL} -eq 0 ]; do
  sleep ${SLEEP_NAT_PENDING}
  nc -w 1 -z ${IP_ADDRESS_NAT} 22 || true
  RETVAL=$?
done

# data init

#bash instances-init.sh ${ENVIRONMENT} dummy

exit 0
