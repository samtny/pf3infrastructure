#!/bin/bash

set -e

[ "$DEFAULTS_LOADED" = "" ] && source defaults.sh

USAGE="Usage: vpcs-get.sh [project]"

if [ $# -ne 1 ]; then
  echo "$USAGE"
  exit 1
fi

PROJECT=$1

# vpc

DESCRIBE_VPCS=$(aws ec2 describe-vpcs --output text --filters Name=tag:Name,Values=$PROJECT)

VPC_ID=$(echo "$DESCRIBE_VPCS" | grep "^VPCS" | cut -f7)
echo -e "aws_VpcId:\t$VPC_ID"

SUBNET_ID_PRIVATE=$(aws ec2 describe-subnets --output text --filters Name=tag:Name,Values=$PROJECT-private | grep "^SUBNETS" | cut -f9)
echo -e "aws_SubnetIdPrivate:\t$SUBNET_ID_PRIVATE"

SUBNET_ID_PUBLIC=$(aws ec2 describe-subnets --output text --filters Name=tag:Name,Values=$PROJECT-public | grep "^SUBNETS" | cut -f9)
echo -e "aws_SubnetIdPublic:\t$SUBNET_ID_PUBLIC"

SUBNET_ID_PUBLIC_ALT=$(aws ec2 describe-subnets --output text --filters Name=tag:Name,Values=$PROJECT-public-alt | grep "^SUBNETS" | cut -f9)
echo -e "aws_SubnetIdPublicAlt:\t$SUBNET_ID_PUBLIC_ALT"

SECURITY_GROUP_ID_ELB=$(aws ec2 describe-security-groups --output text --filters Name=vpc-id,Values=$VPC_ID Name=tag:Name,Values=$PROJECT-elb | grep "^SECURITYGROUPS" | cut -f3)
echo -e "aws_SecurityGroupIdElb:\t$SECURITY_GROUP_ID_ELB"

SECURITY_GROUP_ID_LAMP=$(aws ec2 describe-security-groups --output text --filters Name=vpc-id,Values=$VPC_ID Name=tag:Name,Values=$PROJECT-lamp | grep "^SECURITYGROUPS" | cut -f3)
echo -e "aws_SecurityGroupIdLamp:\t$SECURITY_GROUP_ID_LAMP"

INSTANCE_ID_NAT=$(aws ec2 describe-instances --output text --filters Name=tag:Name,Values=$PROJECT-any-nat Name=instance-state-name,Values=pending,running | grep "^INSTANCES" | cut -f8)
echo -e "aws_InstanceIdNat:\t$INSTANCE_ID_NAT"

exit 0
