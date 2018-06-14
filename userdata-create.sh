#!/bin/bash

set -e

[ "$DEFAULTS_LOADED" = "" ] && source defaults.sh

USAGE="Usage: userdata-create.sh [project] [environment] [service]"

if [ ! $# = 3 ]; then
  echo "$USAGE"
  exit 1
fi

PROJECT=$1
ENVIRONMENT=$2
SERVICE=$3

WORKING_DIR=./working
mkdir -p $WORKING_DIR

USERDATA_FILE=$WORKING_DIR/$PROJECT-$ENVIRONMENT-$SERVICE

[ -f $USERDATA_FILE ] && rm $USERDATA_FILE

cat userdata/header.global >> $USERDATA_FILE

case $SERVICE in
  "dummy")
    cat userdata/service.global >> $USERDATA_FILE
    ;;
esac

[ -f userdata/$SERVICE ] && cat userdata/$SERVICE >> $USERDATA_FILE

cat userdata/footer.global >> $USERDATA_FILE

sed -i -e "s/%%PROJECT%%/$PROJECT/g" $USERDATA_FILE

echo $USERDATA_FILE

exit 0
