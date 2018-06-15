#!/bin/bash

set -e

USAGE="Usage: provision.sh [project] [environment] [service]"

if [ $# -lt 2 ]; then
  echo "$USAGE"
  exit 1
fi

PROJECT=$1
ENVIRONMENT=$2
SERVICE=$3

[ ! "$PROJECT" = "web" ] && exit 1

LIB_DIR="./lib"
WORKING_DIR="./working"
RESOURCE_PREFIX="$PROJECT-$ENVIRONMENT"
TAGS="$SERVICE"

[ "$TAGS" = "" ] && TAGS=all

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
ssh_args = -F "$WORKING_DIR/$RESOURCE_PREFIX.ssh_config"
pipelining = True
EOM

export ANSIBLE_CONFIG="$ANSIBLE_CONFIG_FILE"

#ansible -i ec2.py -u ubuntu tag_Name_dp_test4_code -m ping -vvvv
#python ec2.py --list --refresh-cache

ansible-playbook -i "$WORKING_DIR/ec2.py" --extra-vars "Project=$PROJECT Environment=$ENVIRONMENT" --tags "$TAGS" ./ansible/site.yml -v

exit 0
