#!/bin/bash

set -e

USAGE="Usage: inventory-prepare.sh [project] [environment]"

if [ $# -ne 2 ]; then
  echo "$USAGE"
  exit 1
fi

PROJECT=$1
ENVIRONMENT=$2

[ ! "$PROJECT" = "web" ] && exit 1

LIB_DIR="./lib"
WORKING_DIR="./working"
RESOURCE_PREFIX="$PROJECT-$ENVIRONMENT"

[ ! -d "$WORKING_DIR" ] && mkdir -p "$WORKING_DIR"

# set up ec2.ini / ec2.py

cp "$LIB_DIR/ec2.py" "$WORKING_DIR/ec2.py"
cp "$LIB_DIR/ec2.ini" "$WORKING_DIR/ec2.ini"

cat >> "$WORKING_DIR/ec2.ini" <<- EOM
instance_filters = tag:Name=$PROJECT-$ENVIRONMENT-*
EOM

exit 0
