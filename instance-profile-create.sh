#!/bin/bash

set -e

USAGE="Usage: instance-profile-create.sh [project] [environment] [service]"

if [ $# -ne 3 ]; then
  echo "$USAGE"
  exit 1
fi

PROJECT=$1
ENVIRONMENT=$2
SERVICE=$3

WORKING_DIR="./working"
RESOURCE_PREFIX="$PROJECT-$ENVIRONMENT"

[ ! -d "$WORKING_DIR" ] && mkdir -p "$WORKING_DIR"

cat > "$WORKING_DIR/$PROJECT-$ENVIRONMENT-$SERVICE.policy" <<- EOM
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:ListAllMyBuckets"],"Resource":"arn:aws:s3:::*"},{"Effect":"Allow","Action":["s3:ListBucket","s3:GetBucketLocation"],"Resource":"arn:aws:s3:::$PROJECT-$ENVIRONMENT-$SERVICE"},{"Effect":"Allow","Action":["s3:PutObject","s3:GetObject","s3:DeleteObject"],"Resource":"arn:aws:s3:::$PROJECT-$ENVIRONMENT-$SERVICE/*"},{"Sid":"AWSCloudTrailCreateLogStream2014110","Effect":"Allow","Action":["logs:CreateLogStream"],"Resource":["arn:aws:logs:us-east-1:816574001671:log-group:$PROJECT-$ENVIRONMENT-$SERVICE:log-stream:$PROJECT-$ENVIRONMENT-$SERVICE*"]},{"Sid":"AWSCloudTrailPutLogEvents20141101","Effect":"Allow","Action":["logs:PutLogEvents"],"Resource":["arn:aws:logs:us-east-1:816574001671:log-group:$PROJECT-$ENVIRONMENT-$SERVICE:log-stream:$PROJECT-$ENVIRONMENT-$SERVICE*"]}]}
EOM

CREATE_POLICY=$(aws iam create-policy --output text --policy-name "$PROJECT-$ENVIRONMENT-$SERVICE" --policy-document "file://$WORKING_DIR/$PROJECT-$ENVIRONMENT-$SERVICE.policy")

POLICY_ARN=$(echo -e "$CREATE_POLICY" | cut -f2)

cat > "$WORKING_DIR/$PROJECT-$ENVIRONMENT-$SERVICE.trust_policy" <<- EOM
{"Version":"2012-10-17","Statement":{"Effect":"Allow","Principal": {"Service": "ec2.amazonaws.com"},"Action": "sts:AssumeRole"}}
EOM

aws iam create-role --role-name "$PROJECT-$ENVIRONMENT-$SERVICE" --assume-role-policy-document "file://$WORKING_DIR/$PROJECT-$ENVIRONMENT-$SERVICE.trust_policy" >> /dev/null

aws iam attach-role-policy --policy-arn "$POLICY_ARN" --role-name "$PROJECT-$ENVIRONMENT-$SERVICE" >> /dev/null

aws iam create-instance-profile --instance-profile-name "$PROJECT-$ENVIRONMENT-$SERVICE" >> /dev/null

aws iam add-role-to-instance-profile --role-name "$PROJECT-$ENVIRONMENT-$SERVICE" --instance-profile-name "$PROJECT-$ENVIRONMENT-$SERVICE" >> /dev/null

echo -e "aws_InstanceProfileName\t${PROJECT}-${ENVIRONMENT}-${SERVICE}"

exit 0
