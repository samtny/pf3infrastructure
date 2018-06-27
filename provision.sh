#!/bin/bash

set -e

USAGE="Usage: provision.sh [config] [project] [environment] [service] [tags]"

if [ $# -lt 3 ]; then
  echo "$USAGE"
  exit 1
fi

CONFIG=$1
PROJECT=$2
ENVIRONMENT=$3
SERVICE=$4
TAGS=$5

CONFIG_FILE=./config/config.${CONFIG}.yml

[ ! -f "${CONFIG_FILE}" ] && echo -e "Invalid config specified, exiting..." && exit 1

cp "${CONFIG_FILE}" ./config.yml

[ ! "$PROJECT" = "web" ] && exit 1

LIB_DIR="./lib"
WORKING_DIR="./working"
RESOURCE_PREFIX="$PROJECT-$ENVIRONMENT"

if [ "$TAGS" = "" ]; then
  if [ "$SERVICE" = "" ]; then
    TAGS=all
  else
    TAGS="$SERVICE"
  fi
fi

[ ! -d "$WORKING_DIR" ] && mkdir -p "$WORKING_DIR"

# set up ec2.ini / ec2.py

./inventory-prepare.sh "$PROJECT" "$ENVIRONMENT"

# run ansible, tunneled through jump box, to provision instances inside private network:

BASTION_EIP=$(./eips-get.sh "$PROJECT" "$ENVIRONMENT" "nat")

SSH_CONFIG_FILE="$WORKING_DIR/$RESOURCE_PREFIX.ssh_config"

cat > ${SSH_CONFIG_FILE} <<- EOM
Host *
    User                   ubuntu
    IdentityFile           ~/.ssh/$PROJECT.pem
    ProxyCommand           ssh -i ~/.ssh/$PROJECT.pem ec2-user@$BASTION_EIP -W %h:%p
EOM

ANSIBLE_CONFIG_FILE="$WORKING_DIR/$RESOURCE_PREFIX.ansible.cfg"

cat > ${ANSIBLE_CONFIG_FILE} <<- EOM
[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -F "$WORKING_DIR/$RESOURCE_PREFIX.ssh_config"
pipelining = True
EOM

export ANSIBLE_CONFIG="$ANSIBLE_CONFIG_FILE"

#ansible -i ec2.py -u ubuntu tag_Name_dp_test4_code -m ping -vvvv
#python ec2.py --list --refresh-cache

ansible-playbook -i "$WORKING_DIR/ec2.py" --extra-vars "project=$PROJECT env=$ENVIRONMENT Project=$PROJECT Environment=$ENVIRONMENT" --tags "$TAGS" ./ansible/site.yml -v

exit 0
