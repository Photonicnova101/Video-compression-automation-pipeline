# AWS Infrastructure Configuration

This directory contains all AWS infrastructure configuration files for the Video Compression Pipeline.

## Directory Structure

```
aws/
├── iam-policies/              # IAM role and policy documents
│   ├── mediaconvert-trust-policy.json
│   ├── mediaconvert-service-policy.json
│   ├── lambda-trust-policy.json
│   ├── lambda-execution-policy.json
│   └── n8n-lambda-invoke-policy.json
├── s3-policies/               # S3 bucket policies
│   ├── compressed-videos-bucket-policy.json
│   ├── temp-processing-bucket-policy.json
│   └── temp-bucket-lifecycle.json
├── scripts/                   # Deployment and setup scripts
│   ├── setup-infrastructure.sh
│   ├── deploy-lambdas.sh
│   └── cleanup.sh
└── README.md                  # This file
```

---

## IAM Policies

### MediaConvert Service Role

**Files:**
- `iam-policies/mediaconvert-trust-policy.json` - Trust policy allowing MediaConvert to assume the role
- `iam-policies/mediaconvert-service-policy.json` - Permissions for S3 access

**Purpose:** Allows MediaConvert to read input files from temp bucket and write output files to compressed bucket.

**Create Role:**
```bash
aws iam create-role \
    --role-name MediaConvertServiceRole \
    --assume-role-policy-document file://iam-policies/mediaconvert-trust-policy.json

aws iam put-role-policy \
    --role-name MediaConvertServiceRole \
    --policy-name MediaConvertServicePolicy \
    --policy-document file://iam-policies/mediaconvert-service-policy.json
```

### Lambda Execution Role

**Files:**
- `iam-policies/lambda-trust-policy.json` - Trust policy allowing Lambda to assume the role
- `iam-policies/lambda-execution-policy.json` - Comprehensive permissions for all Lambda functions

**Purpose:** Provides Lambda functions with permissions to:
- Write CloudWatch logs
- Access S3 buckets
- Create and manage MediaConvert jobs
- Publish SNS notifications
- Invoke other Lambda functions
- Pass IAM roles to MediaConvert

**Create Role:**
```bash
aws iam create-role \
    --role-name LambdaExecutionRole \
    --assume-role-policy-document file://iam-policies/lambda-trust-policy.json

aws iam put-role-policy \
    --role-name LambdaExecutionRole \
    --policy-name LambdaExecutionPolicy \
    --policy-document file://iam-policies/lambda-execution-policy.json
```

### n8n Lambda Invoke Policy

**File:** `iam-policies/n8n-lambda-invoke-policy.json`

**Purpose:** Allows n8n IAM user to invoke the video-file-processor Lambda function.

**Attach to n8n User:**
```bash
aws iam create-user --user-name n8n-lambda-invoker

aws iam put-user-policy \
    --user-name n8n-lambda-invoker \
    --policy-name LambdaInvokePolicy \
    --policy-document file://iam-policies/n8n-lambda-invoke-policy.json

# Create access key for n8n
aws iam create-access-key --user-name n8n-lambda-invoker
```

---

## S3 Bucket Policies

### Compressed Videos Bucket Policy

**File:** `s3-policies/compressed-videos-bucket-policy.json`

**Purpose:** Allows MediaConvert and Lambda services to read/write compressed video files.

**Apply Policy:**
```bash
aws s3api put-bucket-policy \
    --bucket sam-pautrat-compressed-videos \
    --policy file://s3-policies/compressed-videos-bucket-policy.json
```

### Temp Processing Bucket Policy

**File:** `s3-policies/temp-processing-bucket-policy.json`

**Purpose:** Allows Lambda and MediaConvert to read/write/delete temporary files during processing.

**Apply Policy:**
```bash
aws s3api put-bucket-policy \
    --bucket sam-pautrat-temp-processing \
    --policy file://s3-policies/temp-processing-bucket-policy.json
```

### Temp Bucket Lifecycle Policy

**File:** `s3-policies/temp-bucket-lifecycle.json`

**Purpose:** Automatically deletes temporary files after 7 days to reduce storage costs.

**Apply Lifecycle Policy:**
```bash
aws s3api put-bucket-lifecycle-configuration \
    --bucket sam-pautrat-temp-processing \
    --lifecycle-configuration file://s3-policies/temp-bucket-lifecycle.json
```

---

## Quick Setup

### Complete Infrastructure Setup

Run all commands in sequence:

```bash
# Navigate to aws directory
cd aws

# 1. Create S3 buckets
aws s3 mb s3://sam-pautrat-temp-processing --region us-east-1
aws s3 mb s3://sam-pautrat-compressed-videos --region us-east-1

# 2. Create IAM roles
aws iam create-role \
    --role-name MediaConvertServiceRole \
    --assume-role-policy-document file://iam-policies/mediaconvert-trust-policy.json

aws iam put-role-policy \
    --role-name MediaConvertServiceRole \
    --policy-name MediaConvertServicePolicy \
    --policy-document file://iam-policies/mediaconvert-service-policy.json

aws iam create-role \
    --role-name LambdaExecutionRole \
    --assume-role-policy-document file://iam-policies/lambda-trust-policy.json

aws iam put-role-policy \
    --role-name LambdaExecutionRole \
    --policy-name LambdaExecutionPolicy \
    --policy-document file://iam-policies/lambda-execution-policy.json

# 3. Apply S3 bucket policies
aws s3api put-bucket-policy \
    --bucket sam-pautrat-compressed-videos \
    --policy file://s3-policies/compressed-videos-bucket-policy.json

aws s3api put-bucket-policy \
    --bucket sam-pautrat-temp-processing \
    --policy file://s3-policies/temp-processing-bucket-policy.json

# 4. Apply lifecycle policy
aws s3api put-bucket-lifecycle-configuration \
    --bucket sam-pautrat-temp-processing \
    --lifecycle-configuration file://s3-policies/temp-bucket-lifecycle.json

# 5. Create n8n IAM user
aws iam create-user --user-name n8n-lambda-invoker

aws iam put-user-policy \
    --user-name n8n-lambda-invoker \
    --policy-name LambdaInvokePolicy \
    --policy-document file://iam-policies/n8n-lambda-invoke-policy.json

aws iam create-access-key --user-name n8n-lambda-invoker

# 6. Create SNS topic
aws sns create-topic --name video-compression-notifications --region us-east-1

# 7. Create CloudWatch log groups
aws logs create-log-group --log-group-name /aws/lambda/video-file-processor --region us-east-1
aws logs create-log-group --log-group-name /aws/lambda/completion-handler --region us-east-1
aws logs create-log-group --log-group-name /aws/lambda/MetaDataLogger --region us-east-1

echo "AWS infrastructure setup complete!"
```

---

## Verification

### Verify IAM Roles

```bash
# Check MediaConvert role
aws iam get-role --role-name MediaConvertServiceRole
aws iam get-role-policy --role-name MediaConvertServiceRole --policy-name MediaConvertServicePolicy

# Check Lambda role
aws iam get-role --role-name LambdaExecutionRole
aws iam get-role-policy --role-name LambdaExecutionRole --policy-name LambdaExecutionPolicy

# Check n8n user
aws iam get-user --user-name n8n-lambda-invoker
aws iam get-user-policy --user-name n8n-lambda-invoker --policy-name LambdaInvokePolicy
```

### Verify S3 Buckets

```bash
# List buckets
aws s3 ls | grep sam-pautrat

# Check bucket policies
aws s3api get-bucket-policy --bucket sam-pautrat-temp-processing
aws s3api get-bucket-policy --bucket sam-pautrat-compressed-videos

# Check lifecycle configuration
aws s3api get-bucket-lifecycle-configuration --bucket sam-pautrat-temp-processing
```

### Verify SNS Topic

```bash
aws sns list-topics | grep video-compression
```

---

## Cleanup

To remove all infrastructure:

```bash
# WARNING: This will delete all buckets and their contents!

# Delete S3 bucket contents
aws s3 rm s3://sam-pautrat-temp-processing --recursive
aws s3 rm s3://sam-pautrat-compressed-videos --recursive

# Delete S3 buckets
aws s3 rb s3://sam-pautrat-temp-processing
aws s3 rb s3://sam-pautrat-compressed-videos

# Delete IAM roles
aws iam delete-role-policy --role-name MediaConvertServiceRole --policy-name MediaConvertServicePolicy
aws iam delete-role --role-name MediaConvertServiceRole

aws iam delete-role-policy --role-name LambdaExecutionRole --policy-name LambdaExecutionPolicy
aws iam delete-role --role-name LambdaExecutionRole

# Delete n8n user
aws iam delete-user-policy --user-name n8n-lambda-invoker --policy-name LambdaInvokePolicy
# Note: Delete access keys first before deleting user
aws iam list-access-keys --user-name n8n-lambda-invoker
aws iam delete-access-key --user-name n8n-lambda-invoker --access-key-id ACCESS_KEY_ID
aws iam delete-user --user-name n8n-lambda-invoker

# Delete SNS topic
aws sns delete-topic --topic-arn arn:aws:sns:us-east-1:ACCOUNT-ID:video-compression-notifications

# Delete CloudWatch log groups
aws logs delete-log-group --log-group-name /aws/lambda/video-file-processor
aws logs delete-log-group --log-group-name /aws/lambda/completion-handler
aws logs delete-log-group --log-group-name /aws/lambda/MetaDataLogger
```

---

## Security Best Practices

1. **Least Privilege**: Policies grant minimum required permissions
2. **Resource Restrictions**: Policies limited to specific S3 buckets and Lambda functions
3. **Service Principals**: Use AWS service principals instead of user credentials where possible
4. **Condition Keys**: IAM PassRole restricted to MediaConvert service
5. **Encryption**: Enable S3 bucket encryption (SSE-S3 or SSE-KMS)
6. **Access Logging**: Enable S3 access logging for audit trails
7. **Versioning**: Enable S3 versioning for data protection
8. **MFA Delete**: Enable MFA delete on production buckets

---

## Troubleshooting

### Issue: Access Denied errors

```bash
# Check if role exists
aws iam get-role --role-name ROLE_NAME

# Verify policy is attached
aws iam get-role-policy --role-name ROLE_NAME --policy-name POLICY_NAME

# Test policy simulation
aws iam simulate-principal-policy \
    --policy-source-arn arn:aws:iam::ACCOUNT-ID:role/ROLE_NAME \
    --action-names ACTION_NAME \
    --resource-arns RESOURCE_ARN
```

### Issue: Bucket policy errors

```bash
# Validate JSON
cat s3-policies/POLICY_FILE.json | python -m json.tool

# Check bucket exists
aws s3 ls s3://BUCKET_NAME

# View current policy
aws s3api get-bucket-policy --bucket BUCKET_NAME
```

---

## Related Documentation

- [Main README](../README.md)
- [Configuration Guide](../docs/CONFIGURATION.md)
- [Lambda Functions](../lambda-functions/README.md)
- [Troubleshooting Guide](../docs/TROUBLESHOOTING.md)
