#!/bin/bash

set -e

[ "$DEFAULTS_LOADED" = "" ] && source defaults.sh

USAGE="Usage: keypair-create.sh [project]"

if [ $# -ne 1 ]; then
  echo "$USAGE"
  exit 1
fi

PROJECT=$1

PEM=~/.ssh/$PROJECT.pem

if [ -f $PEM ]; then
  exit 1
fi

touch $PEM && chmod 600 $PEM

aws ec2 create-key-pair --output text --key-name $PROJECT >> $PEM

#chmod 400 $PEM

exit 0
