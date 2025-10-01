#!/bin/bash

# Video Compression Pipeline - Infrastructure Setup Script
# This script sets up all AWS infrastructure required for the pipeline

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REGION="us-east-1"
BUCKET_PREFIX="sam-pautrat"
PROJECT_NAME="video-compression-pipeline"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Video Compression Pipeline Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials are not configured${NC}"
    echo "Please run: aws configure"
    exit 1
fi

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
echo -e "${GREEN}✓${NC} AWS Account ID: ${ACCOUNT_ID}"
echo ""

# Step 1: Create S3 Buckets
echo -e "${YELLOW}Step 1: Creating S3 Buckets...${NC}"

if aws s3 ls "s3://${BUCKET_PREFIX}-temp-processing" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3 mb "s3://${BUCKET_PREFIX}-temp-processing" --region ${REGION}
    echo -e "${GREEN}✓${NC} Created temp processing bucket"
else
    echo -e "${YELLOW}⚠${NC} Temp processing bucket already exists"
fi

if aws s3 ls "s3://${BUCKET_PREFIX}-compressed-videos" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3 mb "s3://${BUCKET_PREFIX}-compressed-videos" --region ${REGION}
    echo -e "${GREEN}✓${NC} Created compressed videos bucket"
else
    echo -e "${YELLOW}⚠${NC} Compressed videos bucket already exists"
fi

echo ""

# Step 2: Create IAM Roles
echo -e "${YELLOW}Step 2: Creating IAM Roles...${NC}"

# MediaConvert Service Role
if ! aws iam get-role --role-name MediaConvertServiceRole &> /dev/null; then
    aws iam create-role \
        --role-name MediaConvertServiceRole \
        --assume-role-policy-document file://iam-policies/mediaconvert-trust-policy.json \
        --tags Key=Project,Value=${PROJECT_NAME}
    
    # Wait for role to be created
    sleep 5
    
    aws iam put-role-policy \
        --role-name MediaConvertServiceRole \
        --policy-name MediaConvertServicePolicy \
        --policy-document file://iam-policies/mediaconvert-service-policy.json
    
    echo -e "${GREEN}✓${NC} Created MediaConvertServiceRole"
else
    echo -e "${YELLOW}⚠${NC} MediaConvertServiceRole already exists"
fi

# Lambda Execution Role
if ! aws iam get-role --role-name LambdaExecutionRole &> /dev/null; then
    aws iam create-role \
        --role-name LambdaExecutionRole \
        --assume-role-policy-document file://iam-policies/lambda-trust-policy.json \
        --tags Key=Project,Value=${PROJECT_NAME}
    
    # Wait for role to be created
    sleep 5
    
    aws iam put-role-policy \
        --role-name LambdaExecutionRole \
        --policy-name LambdaExecutionPolicy \
        --policy-document file://iam-policies/lambda-execution-policy.json
    
    echo -e "${GREEN}✓${NC} Created LambdaExecutionRole"
else
    echo -e "${YELLOW}⚠${NC} LambdaExecutionRole already exists"
fi

echo ""

# Step 3: Apply S3 Bucket Policies
echo -e "${YELLOW}Step 3: Applying S3 Bucket Policies...${NC}"

aws s3api put-bucket-policy \
    --bucket "${BUCKET_PREFIX}-compressed-videos" \
    --policy file://s3-policies/compressed-videos-bucket-policy.json

echo -e "${GREEN}✓${NC} Applied policy to compressed videos bucket"

aws s3api put-bucket-policy \
    --bucket "${BUCKET_PREFIX}-temp-processing" \
    --policy file://s3-policies/temp-processing-bucket-policy.json

echo -e "${GREEN}✓${NC} Applied policy to temp processing bucket"

echo ""

# Step 4: Apply S3 Lifecycle Policy
echo -e "${YELLOW}Step 4: Applying S3 Lifecycle Policy...${NC}"

aws s3api put-bucket-lifecycle-configuration \
    --bucket "${BUCKET_PREFIX}-temp-processing" \
    --lifecycle-configuration file://s3-policies/temp-bucket-lifecycle.json

echo -e "${GREEN}✓${NC} Applied lifecycle policy to temp bucket"

echo ""

# Step 5: Create SNS Topic
echo -e "${YELLOW}Step 5: Creating SNS Topic...${NC}"

SNS_TOPIC_ARN=$(aws sns create-topic \
    --name video-compression-notifications \
    --region ${REGION} \
    --query 'TopicArn' \
    --output text 2>/dev/null || aws sns list-topics \
    --query "Topics[?contains(TopicArn, 'video-compression-notifications')].TopicArn" \
    --output text)

if [ -n "$SNS_TOPIC_ARN" ]; then
    echo -e "${GREEN}✓${NC} SNS Topic ARN: ${SNS_TOPIC_ARN}"
    echo ""
    echo -e "${YELLOW}Subscribe your email to the SNS topic:${NC}"
    echo "aws sns subscribe \\"
    echo "    --topic-arn ${SNS_TOPIC_ARN} \\"
    echo "    --protocol email \\"
    echo "    --notification-endpoint your-email@example.com"
else
    echo -e "${RED}✗${NC} Failed to create/retrieve SNS topic"
fi

echo ""

# Step 6: Create CloudWatch Log Groups
echo -e "${YELLOW}Step 6: Creating CloudWatch Log Groups...${NC}"

for log_group in "/aws/lambda/video-file-processor" "/aws/lambda/completion-handler" "/aws/lambda/MetaDataLogger"; do
    if ! aws logs describe-log-groups --log-group-name-prefix ${log_group} --region ${REGION} | grep -q ${log_group}; then
        aws logs create-log-group --log-group-name ${log_group} --region ${REGION}
        echo -e "${GREEN}✓${NC} Created log group: ${log_group}"
    else
        echo -e "${YELLOW}⚠${NC} Log group already exists: ${log_group}"
    fi
done

echo ""

# Step 7: Get MediaConvert Endpoint
echo -e "${YELLOW}Step 7: Getting MediaConvert Endpoint...${NC}"

MEDIACONVERT_ENDPOINT=$(aws mediaconvert describe-endpoints --region ${REGION} --query "Endpoints[0].Url" --output text)

if [ -n "$MEDIACONVERT_ENDPOINT" ]; then
    echo -e "${GREEN}✓${NC} MediaConvert Endpoint: ${MEDIACONVERT_ENDPOINT}"
else
    echo -e "${RED}✗${NC} Failed to retrieve MediaConvert endpoint"
fi

echo ""

# Step 8: Create n8n IAM User
echo -e "${YELLOW}Step 8: Creating n8n IAM User...${NC}"

if ! aws iam get-user --user-name n8n-lambda-invoker &> /dev/null; then
    aws iam create-user \
        --user-name n8n-lambda-invoker \
        --tags Key=Project,Value=${PROJECT_NAME}
    
    # Wait for user to be created
    sleep 3
    
    aws iam put-user-policy \
        --user-name n8n-lambda-invoker \
        --policy-name LambdaInvokePolicy \
        --policy-document file://iam-policies/n8n-lambda-invoke-policy.json
    
    echo -e "${GREEN}✓${NC} Created n8n IAM user"
    echo ""
    echo -e "${YELLOW}Create access key for n8n:${NC}"
    echo "aws iam create-access-key --user-name n8n-lambda-invoker"
else
    echo -e "${YELLOW}⚠${NC} n8n IAM user already exists"
fi

echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Important Information:${NC}"
echo ""
echo "Account ID:              ${ACCOUNT_ID}"
echo "Region:                  ${REGION}"
echo "Temp Bucket:             ${BUCKET_PREFIX}-temp-processing"
echo "Compressed Bucket:       ${BUCKET_PREFIX}-compressed-videos"
echo "MediaConvert Endpoint:   ${MEDIACONVERT_ENDPOINT}"
echo "SNS Topic ARN:           ${SNS_TOPIC_ARN}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Subscribe your email to SNS topic (see command above)"
echo "2. Create access key for n8n user (see command above)"
echo "3. Deploy Lambda functions (run deploy-lambdas.sh)"
echo "4. Configure n8n workflow"
echo "5. Set up Airtable base"
echo ""
echo -e "${GREEN}Save these values - you'll need them for Lambda environment variables!${NC}"
