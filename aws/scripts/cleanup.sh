#!/bin/bash

# Video Compression Pipeline - Cleanup Script
# This script removes all AWS infrastructure created by the pipeline
# WARNING: This will delete all S3 buckets and their contents!

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REGION="us-east-1"
BUCKET_PREFIX="sam-pautrat"

echo -e "${RED}========================================${NC}"
echo -e "${RED}Video Compression Pipeline Cleanup${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${RED}WARNING: This will DELETE all infrastructure!${NC}"
echo -e "${RED}This includes:${NC}"
echo "  - S3 buckets and ALL their contents"
echo "  - Lambda functions"
echo "  - IAM roles and policies"
echo "  - SNS topics"
echo "  - CloudWatch log groups"
echo "  - EventBridge rules"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " -r
echo

if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting cleanup...${NC}"
echo ""

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
echo "Account ID: ${ACCOUNT_ID}"
echo ""

# Step 1: Delete Lambda functions
echo -e "${YELLOW}Step 1: Deleting Lambda functions...${NC}"

for function in "video-file-processor" "completion-handler" "MetaDataLogger"; do
    if aws lambda get-function --function-name ${function} --region ${REGION} &> /dev/null; then
        aws lambda delete-function --function-name ${function} --region ${REGION}
        echo -e "${GREEN}✓${NC} Deleted ${function}"
    else
        echo -e "${YELLOW}⚠${NC} ${function} not found"
    fi
done

echo ""

# Step 2: Delete EventBridge rule
echo -e "${YELLOW}Step 2: Deleting EventBridge rule...${NC}"

if aws events describe-rule --name MediaConvertJobStateChange --region ${REGION} &> /dev/null; then
    # Remove targets first
    aws events remove-targets \
        --rule MediaConvertJobStateChange \
        --ids "1" \
        --region ${REGION} &> /dev/null || true
    
    # Delete rule
    aws events delete-rule \
        --name MediaConvertJobStateChange \
        --region ${REGION}
    
    echo -e "${GREEN}✓${NC} Deleted EventBridge rule"
else
    echo -e "${YELLOW}⚠${NC} EventBridge rule not found"
fi

echo ""

# Step 3: Delete CloudWatch Log Groups
echo -e "${YELLOW}Step 3: Deleting CloudWatch Log Groups...${NC}"

for log_group in "/aws/lambda/video-file-processor" "/aws/lambda/completion-handler" "/aws/lambda/MetaDataLogger"; do
    if aws logs describe-log-groups --log-group-name-prefix ${log_group} --region ${REGION} | grep -q ${log_group}; then
        aws logs delete-log-group --log-group-name ${log_group} --region ${REGION}
        echo -e "${GREEN}✓${NC} Deleted ${log_group}"
    else
        echo -e "${YELLOW}⚠${NC} ${log_group} not found"
    fi
done

echo ""

# Step 4: Delete SNS Topic
echo -e "${YELLOW}Step 4: Deleting SNS Topic...${NC}"

SNS_TOPIC_ARN=$(aws sns list-topics --region ${REGION} --query "Topics[?contains(TopicArn, 'video-compression-notifications')].TopicArn" --output text)

if [ -n "$SNS_TOPIC_ARN" ]; then
    aws sns delete-topic --topic-arn ${SNS_TOPIC_ARN} --region ${REGION}
    echo -e "${GREEN}✓${NC} Deleted SNS topic"
else
    echo -e "${YELLOW}⚠${NC} SNS topic not found"
fi

echo ""

# Step 5: Delete S3 Buckets
echo -e "${YELLOW}Step 5: Deleting S3 Buckets...${NC}"

# Delete temp processing bucket
if aws s3 ls "s3://${BUCKET_PREFIX}-temp-processing" &> /dev/null; then
    echo "  Emptying temp processing bucket..."
    aws s3 rm "s3://${BUCKET_PREFIX}-temp-processing" --recursive --region ${REGION}
    aws s3 rb "s3://${BUCKET_PREFIX}-temp-processing" --region ${REGION}
    echo -e "${GREEN}✓${NC} Deleted temp processing bucket"
else
    echo -e "${YELLOW}⚠${NC} Temp processing bucket not found"
fi

# Delete compressed videos bucket
if aws s3 ls "s3://${BUCKET_PREFIX}-compressed-videos" &> /dev/null; then
    echo "  Emptying compressed videos bucket..."
    aws s3 rm "s3://${BUCKET_PREFIX}-compressed-videos" --recursive --region ${REGION}
    aws s3 rb "s3://${BUCKET_PREFIX}-compressed-videos" --region ${REGION}
    echo -e "${GREEN}✓${NC} Deleted compressed videos bucket"
else
    echo -e "${YELLOW}⚠${NC} Compressed videos bucket not found"
fi

echo ""

# Step 6: Delete IAM Roles
echo -e "${YELLOW}Step 6: Deleting IAM Roles...${NC}"

# Delete MediaConvert Service Role
if aws iam get-role --role-name MediaConvertServiceRole &> /dev/null; then
    # Delete inline policies first
    aws iam delete-role-policy \
        --role-name MediaConvertServiceRole \
        --policy-name MediaConvertServicePolicy &> /dev/null || true
    
    # Delete role
    aws iam delete-role --role-name MediaConvertServiceRole
    echo -e "${GREEN}✓${NC} Deleted MediaConvertServiceRole"
else
    echo -e "${YELLOW}⚠${NC} MediaConvertServiceRole not found"
fi

# Delete Lambda Execution Role
if aws iam get-role --role-name LambdaExecutionRole &> /dev/null; then
    # Delete inline policies first
    aws iam delete-role-policy \
        --role-name LambdaExecutionRole \
        --policy-name LambdaExecutionPolicy &> /dev/null || true
    
    # Delete role
    aws iam delete-role --role-name LambdaExecutionRole
    echo -e "${GREEN}✓${NC} Deleted LambdaExecutionRole"
else
    echo -e "${YELLOW}⚠${NC} LambdaExecutionRole not found"
fi

echo ""

# Step 7: Delete n8n IAM User
echo -e "${YELLOW}Step 7: Deleting n8n IAM User...${NC}"

if aws iam get-user --user-name n8n-lambda-invoker &> /dev/null; then
    # Delete inline policies
    aws iam delete-user-policy \
        --user-name n8n-lambda-invoker \
        --policy-name LambdaInvokePolicy &> /dev/null || true
    
    # Delete access keys
    ACCESS_KEYS=$(aws iam list-access-keys --user-name n8n-lambda-invoker --query 'AccessKeyMetadata[].AccessKeyId' --output text)
    for key in ${ACCESS_KEYS}; do
        aws iam delete-access-key --user-name n8n-lambda-invoker --access-key-id ${key}
        echo -e "${GREEN}✓${NC} Deleted access key: ${key}"
    done
    
    # Delete user
    aws iam delete-user --user-name n8n-lambda-invoker
    echo -e "${GREEN}✓${NC} Deleted n8n IAM user"
else
    echo -e "${YELLOW}⚠${NC} n8n IAM user not found"
fi

echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "All infrastructure has been removed from AWS."
echo ""
echo -e "${YELLOW}Don't forget to:${NC}"
echo "• Delete Airtable base if no longer needed"
echo "• Remove n8n workflow"
echo "• Unsubscribe from SNS email notifications (if still receiving emails)"
echo ""
echo -e "${
