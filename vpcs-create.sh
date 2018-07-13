#!/bin/bash

set -e

[ "$DEFAULTS_LOADED" = "" ] && source defaults.sh

USAGE="Usage: vpcs-create.sh [project]"

if [ ! "$#" -eq  1 ]; then
  echo "$USAGE"
  exit 1
fi

PROJECT=$1

SLEEP_INSTANCE_PENDING=10

AVAILABILITY_ZONE_PRIVATE="us-east-1a"
AVAILABILITY_ZONE_PRIVATE_ALT="us-east-1b"
AVAILABILITY_ZONE_PUBLIC="us-east-1a"
AVAILABILITY_ZONE_PUBLIC_ALT="us-east-1b"

echo -e "aws_AvailabilityZonePrivate:\t${AVAILABILITY_ZONE_PRIVATE}"
echo -e "aws_AvailabilityZonePrivateAlt:\t${AVAILABILITY_ZONE_PRIVATE_ALT}"
echo -e "aws_AvailabilityZonePublic:\t${AVAILABILITY_ZONE_PUBLIC}"
echo -e "aws_AvailabilityZonePublicAlt:\t${AVAILABILITY_ZONE_PUBLIC_ALT}"

CIDR_BLOCK_WORLD=0.0.0.0/0

CIDR_BLOCK_OFFICE=208.91.0.0/16

CIDR_BLOCK_VPC=10.0.0.0/16

CIDR_BLOCK_PRIVATE=10.0.0.0/20
CIDR_BLOCK_PRIVATE_ALT=10.0.16.0/20
CIDR_BLOCK_PUBLIC=10.0.32.0/20
CIDR_BLOCK_PUBLIC_ALT=10.0.64.0/20

THIS_IP_PROVIDER=ipinfo.io/ip

CIDR_BLOCK_THIS="$(curl -s ${THIS_IP_PROVIDER})/32"

PORT_SSH=22
PORT_HTTP=80
PORT_HTTPS=443
PORT_SMTP=25
PORT_SMTP_TLS=587
PORT_APNS=2195
PORT_APNS_FEEDBACK=2196

TAGS="Key=Project,Value=${PROJECT} Key=Name,Value=${PROJECT}"

VPC_ID=$(aws ec2 create-vpc --cidr-block ${CIDR_BLOCK_VPC} | grep VpcId | cut -d':' -f2 | cut -d'"' -f2)

RETVAL=-1
while [ $RETVAL -ne 0 ]; do
  sleep ${EC2_CREATE_RESOURCE_SLEEP_DEFAULT}
  (aws ec2 describe-vpcs --vpc-ids ${VPC_ID} >/dev/null || true)
  RETVAL=$?
done

aws ec2 create-tags --tags ${TAGS} --resources ${VPC_ID} >/dev/null 

echo -e "aws_VpcId:\t${VPC_ID}"

# subnets

SUBNET_ID_PRIVATE=$(./subnets-create.sh $(echo ${PROJECT})-private ${VPC_ID} ${CIDR_BLOCK_PRIVATE} ${AVAILABILITY_ZONE_PRIVATE} | grep aws_SubnetId | cut -f2)
echo -e "aws_SubnetIdPrivate:\t${SUBNET_ID_PRIVATE}"

SUBNET_ID_PRIVATE_ALT=$(./subnets-create.sh $(echo ${PROJECT})-private-alt ${VPC_ID} ${CIDR_BLOCK_PRIVATE_ALT} ${AVAILABILITY_ZONE_PRIVATE_ALT} | grep aws_SubnetId | cut -f2)
echo -e "aws_SubnetIdPrivateAlt:\t${SUBNET_ID_PRIVATE_ALT}"

SUBNET_ID_PUBLIC=$(./subnets-create.sh $(echo ${PROJECT})-public ${VPC_ID} ${CIDR_BLOCK_PUBLIC} ${AVAILABILITY_ZONE_PUBLIC} | grep aws_SubnetId | cut -f2)
echo -e "aws_SubnetIdPublic:\t${SUBNET_ID_PUBLIC}"

SUBNET_ID_PUBLIC_ALT=$(./subnets-create.sh $(echo ${PROJECT})-public-alt ${VPC_ID} ${CIDR_BLOCK_PUBLIC_ALT} ${AVAILABILITY_ZONE_PUBLIC_ALT} | grep aws_SubnetId | cut -f2)
echo -e "aws_SubnetIdPublicAlt:\t${SUBNET_ID_PUBLIC_ALT}"

# security groups

SECGRP_ID_NAT=$(./securitygroups-create.sh ${PROJECT}-nat ${VPC_ID} | grep aws_SecurityGroupId | cut -f2)
echo -e "aws_SecurityGroupIdNat:\t${SECGRP_ID_NAT}"

SECGRP_ID_ELB=$(./securitygroups-create.sh ${PROJECT}-elb ${VPC_ID} | grep aws_SecurityGroupId | cut -f2)
echo -e "aws_SecurityGroupIdElb:\t${SECGRP_ID_ELB}"

SECGRP_ID_LAMP=$(./securitygroups-create.sh ${PROJECT}-lamp ${VPC_ID} | grep aws_SecurityGroupId | cut -f2)
echo -e "aws_SecurityGroupIdLamp:\t${SECGRP_ID_LAMP}"

# security group ingress

# NAT can telnet to all (using as bastion / jump box);
aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_LAMP} --source-group ${SECGRP_ID_NAT} --protocol tcp --port ${PORT_SSH} >/dev/null

# telnet to NAT from office / this ip
aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_NAT} --cidr ${CIDR_BLOCK_OFFICE} --protocol tcp --port ${PORT_SSH} >/dev/null 
aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_NAT} --cidr ${CIDR_BLOCK_THIS} --protocol tcp --port ${PORT_SSH} >/dev/null

# world can reach ELB at 80, 443
aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr ${CIDR_BLOCK_WORLD} --protocol tcp --port ${PORT_HTTP} >/dev/null
aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr ${CIDR_BLOCK_WORLD} --protocol tcp --port ${PORT_HTTPS} >/dev/null

# EC2 IPS can reach ELB at 80, ${PORT_HTTPS} =
# curl -s https://ip-ranges.amazonaws.com/ip-ranges.json | jq '.prefixes[] | select(.region=="us-east-1" and .service=="EC2")' | grep ip_prefix | cut -d' ' -f4 | cut -d'"' -f2 | xargs -I {} echo "aws ec2 authorize-security-group-ingress --group-id \${SECGRP_ID_ELB} --cidr {}  --protocol tcp --port ${PORT_HTTP} >/dev/null"
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 23.20.0.0/14  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 50.16.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 50.19.0.0/16  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 52.0.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 52.2.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 52.4.0.0/14  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 52.20.0.0/14  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 52.70.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 52.72.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 52.86.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 52.90.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 52.95.245.0/24  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 52.95.255.80/28  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 52.200.0.0/13  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.80.0.0/13  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.88.0.0/14  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.92.128.0/17  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.144.0.0/14  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.152.0.0/16  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.156.0.0/14  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.160.0.0/13  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.172.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.174.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.196.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.198.0.0/16  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.204.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.208.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.210.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.221.0.0/16  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.224.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.226.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.234.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.236.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 54.242.0.0/15  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 67.202.0.0/18  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 72.44.32.0/19  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 75.101.128.0/17  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 107.20.0.0/14  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 174.129.0.0/16  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 184.72.64.0/18  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 184.72.128.0/17  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 184.73.0.0/16  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 204.236.192.0/18  --protocol tcp --port ${PORT_HTTP} >/dev/null
#aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_ELB} --cidr 216.182.224.0/20  --protocol tcp --port ${PORT_HTTP} >/dev/null

# private subnets can get out through various ports via NAT instance
aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_NAT} --cidr ${CIDR_BLOCK_PRIVATE} --protocol tcp --port ${PORT_HTTP} >/dev/null
aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_NAT} --cidr ${CIDR_BLOCK_PRIVATE} --protocol tcp --port ${PORT_HTTPS} >/dev/null

aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_NAT} --cidr ${CIDR_BLOCK_PRIVATE_ALT} --protocol tcp --port ${PORT_HTTP} >/dev/null
aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_NAT} --cidr ${CIDR_BLOCK_PRIVATE_ALT} --protocol tcp --port ${PORT_HTTPS} >/dev/null

aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_NAT} --source-group ${SECGRP_ID_LAMP} --protocol tcp --port ${PORT_SMTP} >/dev/null
aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_NAT} --source-group ${SECGRP_ID_LAMP} --protocol tcp --port ${PORT_SMTP_TLS} >/dev/null

aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_NAT} --source-group ${SECGRP_ID_LAMP} --protocol tcp --port ${PORT_APNS} >/dev/null
aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_NAT} --source-group ${SECGRP_ID_LAMP} --protocol tcp --port ${PORT_APNS_FEEDBACK} >/dev/null

# allow misc ports "out" through NAT
aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_NAT} --source-group ${SECGRP_ID_LAMP} --protocol tcp --port 8080 >/dev/null

# ELB's can reach LAMP at various ports;
aws ec2 authorize-security-group-ingress --group-id ${SECGRP_ID_LAMP} --source-group ${SECGRP_ID_ELB} --protocol tcp --port ${PORT_HTTP} >/dev/null

# security group egress

aws ec2 authorize-security-group-egress --port ${PORT_SSH} --protocol tcp --cidr ${CIDR_BLOCK_WORLD} --group-id ${SECGRP_ID_NAT} >/dev/null
aws ec2 authorize-security-group-egress --port ${PORT_HTTP} --protocol tcp --cidr ${CIDR_BLOCK_WORLD} --group-id ${SECGRP_ID_NAT} >/dev/null
aws ec2 authorize-security-group-egress --port ${PORT_HTTPS} --protocol tcp --cidr ${CIDR_BLOCK_WORLD} --group-id ${SECGRP_ID_NAT} >/dev/null
aws ec2 authorize-security-group-egress --port ${PORT_SMTP} --protocol tcp --cidr ${CIDR_BLOCK_WORLD} --group-id ${SECGRP_ID_NAT} >/dev/null
aws ec2 authorize-security-group-egress --port ${PORT_SMTP_TLS} --protocol tcp --cidr ${CIDR_BLOCK_WORLD} --group-id ${SECGRP_ID_NAT} >/dev/null
aws ec2 authorize-security-group-egress --port ${PORT_APNS} --protocol tcp --cidr ${CIDR_BLOCK_WORLD} --group-id ${SECGRP_ID_NAT} >/dev/null
aws ec2 authorize-security-group-egress --port ${PORT_APNS_FEEDBACK} --protocol tcp --cidr ${CIDR_BLOCK_WORLD} --group-id ${SECGRP_ID_NAT} >/dev/null
aws ec2 authorize-security-group-egress --port 8080 --protocol tcp --cidr ${CIDR_BLOCK_WORLD} --group-id ${SECGRP_ID_NAT} >/dev/null
aws ec2 authorize-security-group-egress --port 8081 --protocol tcp --cidr ${CIDR_BLOCK_WORLD} --group-id ${SECGRP_ID_NAT} >/dev/null
aws ec2 authorize-security-group-egress --port 8153 --protocol tcp --cidr ${CIDR_BLOCK_WORLD} --group-id ${SECGRP_ID_NAT} >/dev/null
aws ec2 authorize-security-group-egress --port 8154 --protocol tcp --cidr ${CIDR_BLOCK_WORLD} --group-id ${SECGRP_ID_NAT} >/dev/null
aws ec2 revoke-security-group-egress --protocol -1 --cidr ${CIDR_BLOCK_WORLD} --group-id ${SECGRP_ID_NAT} >/dev/null

# gateway + public route table + public route table associations + public routes 

GATEWAY_ID=$(./gateways-create.sh ${PROJECT} ${VPC_ID} | grep aws_GatewayId | cut -f2)
echo -e "aws_InternetGatewayId:\t${GATEWAY_ID}"

ROUTE_TABLE_ID_PUBLIC=$(./routetables-create.sh ${PROJECT}-public ${VPC_ID} | grep aws_RouteTableId | cut -f2)
echo -e "aws_RouteTableIdPublic:\t${ROUTE_TABLE_ID_PUBLIC}"

aws ec2 associate-route-table --subnet-id ${SUBNET_ID_PUBLIC} --route-table-id ${ROUTE_TABLE_ID_PUBLIC} >/dev/null 
aws ec2 associate-route-table --subnet-id ${SUBNET_ID_PUBLIC_ALT} --route-table-id ${ROUTE_TABLE_ID_PUBLIC} >/dev/null

aws ec2 create-route --route-table-id ${ROUTE_TABLE_ID_PUBLIC} --destination-cidr-block ${CIDR_BLOCK_WORLD} --gateway-id ${GATEWAY_ID} >/dev/null 

# nat instance + private route table + private route table associations + private routes

INSTANCE_ID_NAT=$(bash instances-create.sh ${PROJECT} any nat ${VPC_ID} ${SECGRP_ID_NAT} ${SUBNET_ID_PUBLIC} "" ${EC2_INSTANCE_TYPE_NAT} "${EC2_AMI_NAT}" | grep aws_InstanceId | cut -f2)
while [ "$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID_NAT} --output text | grep STATE | grep -v STATEREASON | cut -f3)" = "pending" ]; do
  sleep ${EC2_CREATE_RESOURCE_SLEEP_DEFAULT}
done
aws ec2 modify-instance-attribute --instance-id ${INSTANCE_ID_NAT} --no-source-dest-check >/dev/null
echo -e "aws_InstanceIdNat:\t${INSTANCE_ID_NAT}"

ALLOCATION_ID_NAT=$(aws ec2 allocate-address --domain vpc | grep AllocationId | cut -d':' -f2 | cut -d'"' -f2)
while [ ! "$(aws ec2 describe-addresses --output text --allocation-id ${ALLOCATION_ID_NAT} | grep '^ADDRESSES' | cut -f2)" = "${ALLOCATION_ID_NAT}" ]; do
  sleep ${EC2_CREATE_RESOURCE_SLEEP_DEFAULT}
done
aws ec2 associate-address --instance-id ${INSTANCE_ID_NAT} --allocation-id ${ALLOCATION_ID_NAT} >/dev/null
echo -e "aws_AllocationIdNat:\t${ALLOCATION_ID_NAT}"

ROUTE_TABLE_ID_PRIVATE=$(./routetables-create.sh ${PROJECT}-private ${VPC_ID} | grep aws_RouteTableId | cut -f2)
echo -e "aws_RouteTableIdPrivate:\t${ROUTE_TABLE_ID_PRIVATE}"

aws ec2 associate-route-table --subnet-id ${SUBNET_ID_PRIVATE} --route-table-id ${ROUTE_TABLE_ID_PRIVATE} >/dev/null
aws ec2 associate-route-table --subnet-id ${SUBNET_ID_PRIVATE_ALT} --route-table-id ${ROUTE_TABLE_ID_PRIVATE} >/dev/null

aws ec2 create-route --route-table-id ${ROUTE_TABLE_ID_PRIVATE} --destination-cidr-block ${CIDR_BLOCK_WORLD} --instance-id ${INSTANCE_ID_NAT} >/dev/null 

# rds route table associations

#aws ec2 associate-route-table --subnet-id $SUBNET_ID_RDS --route-table-id ${ROUTE_TABLE_ID_PRIVATE} >/dev/null

exit 0
