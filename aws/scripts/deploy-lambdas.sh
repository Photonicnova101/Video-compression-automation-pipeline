#!/bin/bash

# Video Compression Pipeline - Lambda Deployment Script
# This script packages and deploys all Lambda functions

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGION="us-east-1"
LAMBDA_DIR="../lambda-functions"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Lambda Functions Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

# Check if python3 and pip are installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed${NC}"
    exit 1
fi

if ! command -v pip3 &> /dev/null; then
    echo -e "${RED}Error: pip3 is not installed${NC}"
    exit 1
fi

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
echo -e "${GREEN}✓${NC} AWS Account ID: ${ACCOUNT_ID}"

# Get IAM Role ARN
LAMBDA_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/LambdaExecutionRole"
echo -e "${GREEN}✓${NC} Lambda Role ARN: ${LAMBDA_ROLE_ARN}"
echo ""

# Verify role exists
if ! aws iam get-role --role-name LambdaExecutionRole &> /dev/null; then
    echo -e "${RED}Error: LambdaExecutionRole does not exist${NC}"
    echo "Please run setup-infrastructure.sh first"
    exit 1
fi

# Function to package and deploy a Lambda function
deploy_function() {
    local FUNCTION_NAME=$1
    local FUNCTION_DIR="${LAMBDA_DIR}/${FUNCTION_NAME}"
    local TIMEOUT=$2
    local MEMORY=$3
    
    echo -e "${YELLOW}Deploying ${FUNCTION_NAME}...${NC}"
    
    # Check if function directory exists
    if [ ! -d "${FUNCTION_DIR}" ]; then
        echo -e "${RED}✗${NC} Directory not found: ${FUNCTION_DIR}"
        return 1
    fi
    
    # Create temporary package directory
    PACKAGE_DIR="${FUNCTION_DIR}/package"
    mkdir -p ${PACKAGE_DIR}
    
    # Install dependencies
    if [ -f "${FUNCTION_DIR}/requirements.txt" ]; then
        echo "  Installing dependencies..."
        pip3 install -r ${FUNCTION_DIR}/requirements.txt -t ${PACKAGE_DIR} --quiet
    fi
    
    # Copy function code
    cp ${FUNCTION_DIR}/lambda_function.py ${PACKAGE_DIR}/
    
    # Create deployment package
    echo "  Creating deployment package..."
    cd ${PACKAGE_DIR}
    zip -r ../deployment-package.zip . > /dev/null
    cd - > /dev/null
    
    # Check if function exists
    if aws lambda get-function --function-name ${FUNCTION_NAME} --region ${REGION} &> /dev/null; then
        # Update existing function
        echo "  Updating existing function..."
        aws lambda update-function-code \
            --function-name ${FUNCTION_NAME} \
            --zip-file fileb://${FUNCTION_DIR}/deployment-package.zip \
            --region ${REGION} \
            > /dev/null
        
        echo -e "${GREEN}✓${NC} Updated ${FUNCTION_NAME}"
    else
        # Create new function
        echo "  Creating new function..."
        aws lambda create-function \
            --function-name ${FUNCTION_NAME} \
            --runtime python3.9 \
            --role ${LAMBDA_ROLE_ARN} \
            --handler lambda_function.lambda_handler \
            --zip-file fileb://${FUNCTION_DIR}/deployment-package.zip \
            --timeout ${TIMEOUT} \
            --memory-size ${MEMORY} \
            --region ${REGION} \
            --tags Project=video-compression-pipeline \
            > /dev/null
        
        echo -e "${GREEN}✓${NC} Created ${FUNCTION_NAME}"
    fi
    
    # Cleanup
    rm -rf ${PACKAGE_DIR}
    rm -f ${FUNCTION_DIR}/deployment-package.zip
    
    echo ""
}

# Deploy all Lambda functions
echo -e "${BLUE}Deploying Lambda functions...${NC}"
echo ""

# Deploy video-file-processor (15 min timeout, 512 MB memory)
deploy_function "video-file-processor" 900 512

# Deploy completion-handler (5 min timeout, 256 MB memory)
deploy_function "completion-handler" 300 256

# Deploy MetaDataLogger (1 min timeout, 128 MB memory)
deploy_function "MetaDataLogger" 60 128

# Configure environment variables
echo -e "${YELLOW}Configuring environment variables...${NC}"
echo ""

# Get MediaConvert endpoint
MEDIACONVERT_ENDPOINT=$(aws mediaconvert describe-endpoints --region ${REGION} --query "Endpoints[0].Url" --output text)

# Get SNS Topic ARN
SNS_TOPIC_ARN=$(aws sns list-topics --region ${REGION} --query "Topics[?contains(TopicArn, 'video-compression-notifications')].TopicArn" --output text)

# video-file-processor environment variables
echo "  Configuring video-file-processor..."
aws lambda update-function-configuration \
    --function-name video-file-processor \
    --environment "Variables={
        TEMP_BUCKET=sam-pautrat-temp-processing,
        COMPRESSED_BUCKET=sam-pautrat-compressed-videos,
        MEDIACONVERT_ROLE=arn:aws:iam::${ACCOUNT_ID}:role/MediaConvertServiceRole,
        SNS_TOPIC=${SNS_TOPIC_ARN},
        MEDIACONVERT_ENDPOINT=${MEDIACONVERT_ENDPOINT}
    }" \
    --region ${REGION} \
    > /dev/null

echo -e "${GREEN}✓${NC} Configured video-file-processor"

# completion-handler environment variables
echo "  Configuring completion-handler..."
aws lambda update-function-configuration \
    --function-name completion-handler \
    --environment "Variables={
        TEMP_BUCKET=sam-pautrat-temp-processing,
        COMPRESSED_BUCKET=sam-pautrat-compressed-videos,
        SNS_TOPIC=${SNS_TOPIC_ARN},
        METADATA_LOGGER_FUNCTION=MetaDataLogger,
        MEDIACONVERT_ENDPOINT=${MEDIACONVERT_ENDPOINT}
    }" \
    --region ${REGION} \
    > /dev/null

echo -e "${GREEN}✓${NC} Configured completion-handler"

# MetaDataLogger environment variables - needs manual configuration
echo "  ${YELLOW}NOTE: MetaDataLogger needs Airtable credentials${NC}"
echo "  Run this command with your Airtable credentials:"
echo ""
echo "  aws lambda update-function-configuration \\"
echo "      --function-name MetaDataLogger \\"
echo "      --environment 'Variables={"
echo "          AIRTABLE_BASE_ID=YOUR_BASE_ID,"
echo "          AIRTABLE_TABLE_NAME=Processed Videos,"
echo "          AIRTABLE_API_KEY=YOUR_API_KEY"
echo "      }' \\"
echo "      --region ${REGION}"
echo ""

# Set up EventBridge rule
echo -e "${YELLOW}Setting up EventBridge rule...${NC}"

# Create EventBridge rule for MediaConvert
RULE_EXISTS=$(aws events list-rules --region ${REGION} --query "Rules[?Name=='MediaConvertJobStateChange'].Name" --output text)

if [ -z "$RULE_EXISTS" ]; then
    aws events put-rule \
        --name MediaConvertJobStateChange \
        --event-pattern '{
            "source": ["aws.mediaconvert"],
            "detail-type": ["MediaConvert Job State Change"],
            "detail": {
                "status": ["COMPLETE", "ERROR"]
            }
        }' \
        --state ENABLED \
        --region ${REGION} \
        > /dev/null
    
    echo -e "${GREEN}✓${NC} Created EventBridge rule"
else
    echo -e "${YELLOW}⚠${NC} EventBridge rule already exists"
fi

# Add Lambda as target
TARGET_EXISTS=$(aws events list-targets-by-rule \
    --rule MediaConvertJobStateChange \
    --region ${REGION} \
    --query "Targets[?contains(Arn, 'completion-handler')].Id" \
    --output text)

if [ -z "$TARGET_EXISTS" ]; then
    aws events put-targets \
        --rule MediaConvertJobStateChange \
        --targets "Id"="1","Arn"="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:completion-handler" \
        --region ${REGION} \
        > /dev/null
    
    echo -e "${GREEN}✓${NC} Added Lambda target to EventBridge rule"
else
    echo -e "${YELLOW}⚠${NC} Lambda target already exists"
fi

# Grant EventBridge permission to invoke Lambda
PERMISSION_EXISTS=$(aws lambda get-policy \
    --function-name completion-handler \
    --region ${REGION} \
    --query 'Policy' \
    --output text 2>/dev/null | grep -c "mediaconvert-event-invoke" || echo "0")

if [ "$PERMISSION_EXISTS" -eq "0" ]; then
    aws lambda add-permission \
        --function-name completion-handler \
        --statement-id mediaconvert-event-invoke \
        --action lambda:InvokeFunction \
        --principal events.amazonaws.com \
        --source-arn arn:aws:events:${REGION}:${ACCOUNT_ID}:rule/MediaConvertJobStateChange \
        --region ${REGION} \
        > /dev/null
    
    echo -e "${GREEN}✓${NC} Granted EventBridge permission to invoke Lambda"
else
    echo -e "${YELLOW}⚠${NC} EventBridge permission already exists"
fi

echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Deployed Functions:${NC}"
echo "• video-file-processor"
echo "• completion-handler"
echo "• MetaDataLogger"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Configure MetaDataLogger with Airtable credentials (see command above)"
echo "2. Test video-file-processor with a sample event"
echo "3. Configure n8n workflow to invoke video-file-processor"
echo "4. Upload a test video to Google Drive to test the pipeline"
echo ""
echo -e "${YELLOW}Test Commands:${NC}"
echo ""
echo "# Test video-file-processor"
echo "aws lambda invoke \\"
echo "    --function-name video-file-processor \\"
echo "    --payload file://../../examples/sample-event-file-processor.json \\"
echo "    --cli-binary-format raw-in-base64-out \\"
echo "    response.json"
echo ""
echo "# View logs"
echo "aws logs tail /aws/lambda/video-file-processor --follow"
