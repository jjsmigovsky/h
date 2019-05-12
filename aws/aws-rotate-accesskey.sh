#!/bin/bash -e

echo Initializing
if [[ -z "$AWS_PROFILE" ]]; then
  echo "Please set the \$AWS_PROFILE environment variable."
  exit 1
fi

if [[ -z "`which jq`" ]]; then
  echo "Missing Dependency: jq"
  exit 1
fi

if [[ -z "`which aws`" ]]; then
  echo "Missing Dependency: aws-cli"
  exit 1
fi

echo Parsing configuration
CURRENT_ACCESS_KEY=`aws configure get aws_access_key_id --profile $AWS_PROFILE`
CURRENT_SECRET_KEY=`aws configure get aws_secret_access_key --profile $AWS_PROFILE`

echo Communicating with IAM services
ACCESS_KEYS=`aws iam list-access-keys | jq -r '@base64'`
ACCESS_KEY_COUNT=`echo $ACCESS_KEYS | base64 --decode | jq length`
USER_NAME=`echo $ACCESS_KEYS | base64 --decode | jq -r '.AccessKeyMetadata[0]|.UserName'`
if [ $ACCESS_KEY_COUNT -ne 1 ]; then
  echo "FATAL: Must have 1 available AccessKey slot open for rotation."
  exit 1
fi

echo Creating a new IAM user AccessKey for $USER_NAME
NEW_KEY=`aws iam create-access-key | jq -r '@base64'`
NEW_ACCESS_KEY=`echo $NEW_KEY | base64 --decode | jq -r '.AccessKey.AccessKeyId'`
NEW_SECRET_KEY=`echo $NEW_KEY | base64 --decode | jq -r '.AccessKey.SecretAccessKey'`

echo Configuring local credentials file
FILE=~/.aws/credentials
AK_LINE=`grep -n "$CURRENT_ACCESS_KEY" $FILE | cut -d: -f1`
SK_LINE=`grep -n "$CURRENT_SECRET_KEY" $FILE | cut -d: -f1`
sed -i "${AK_LINE}s/.*/aws_access_key_id = $NEW_ACCESS_KEY/" $FILE
sed -i "${SK_LINE}s/.*/aws_secret_access_key = `echo $NEW_SECRET_KEY | sed -e 's:/:\\\\/:g'`/" $FILE

echo Deleting previous AccessKey $CURRENT_ACCESS_KEY
sleep 10 && aws iam delete-access-key --access-key-id $CURRENT_ACCESS_KEY --user-name $USER_NAME
