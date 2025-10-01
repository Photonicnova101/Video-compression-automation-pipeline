# AWS Scripts

This directory contains automation scripts for deploying and managing the Video Compression Pipeline infrastructure.

## Scripts Overview

| Script | Purpose | Run Time |
|--------|---------|----------|
| `setup-infrastructure.sh` | Create all AWS infrastructure | ~2 minutes |
| `deploy-lambdas.sh` | Package and deploy Lambda functions | ~3 minutes |
| `cleanup.sh` | Delete all infrastructure (DESTRUCTIVE) | ~2 minutes |

---

## Prerequisites

Before running these scripts, ensure you have:

- [x] AWS CLI installed and configured
- [x] AWS credentials with admin access
- [x] Python 3.9+ installed
- [x] pip3 installed
- [x] Bash shell (Linux, macOS, or WSL on Windows)

**Verify prerequisites:**
```bash
aws --version
python3 --version
pip3 --version
aws sts get-caller-identity  # Should show your AWS account info
```

---

## Usage

### 1. Setup Infrastructure

**Creates:**
- S3 buckets (temp and compressed)
- IAM roles (MediaConvert and Lambda)
- SNS topic
- CloudWatch log groups
- n8n IAM user

**Run:**
```bash
cd aws/scripts
chmod +x setup-infrastructure.sh
./setup-infrastructure.sh
```

**Expected output:**
```
========================================
Video Compression Pipeline Setup
========================================

✓ AWS Account ID: 123456789012
✓ Created temp processing bucket
✓ Created compressed videos bucket
✓ Created MediaConvertServiceRole
✓ Created LambdaExecutionRole
...
Setup Complete!
```

**After setup:**
1. Subscribe your email to SNS topic
2. Create access key for n8n user
3. Save the MediaConvert endpoint URL
4. Proceed to deploy Lambda functions

---

### 2. Deploy Lambda Functions

**Creates/Updates:**
- video-file-processor Lambda function
- completion-handler Lambda function
- MetaDataLogger Lambda function
- EventBridge rule for MediaConvert
- Environment variables (except Airtable credentials)

**Run:**
```bash
cd aws/scripts
chmod +x deploy-lambdas.sh
./deploy-lambdas.sh
```

**Expected output:**
```
========================================
Lambda Functions Deployment
========================================

✓ AWS Account ID: 123456789012
✓ Lambda Role ARN: arn:aws:iam::...

Deploying video-file-processor...
  Installing dependencies...
  Creating deployment package...
✓ Created video-file-processor
...
Deployment Complete!
```

**After deployment:**
1. Configure Airtable credentials for MetaDataLogger
2. Test Lambda functions
3. Configure n8n workflow

---

### 3. Cleanup (Delete Everything)

**⚠️ WARNING: This is DESTRUCTIVE and IRREVERSIBLE!**

**Deletes:**
- All S3 buckets and their contents
- All Lambda functions
- IAM roles and policies
- SNS topics
- CloudWatch log groups
- EventBridge rules
- n8n IAM user

**Run:**
```bash
cd aws/scripts
chmod +x cleanup.sh
./cleanup.sh
```

**You will be prompted to confirm:**
```
WARNING: This will DELETE all infrastructure!
Are you sure you want to continue? (type 'yes' to confirm):
```

**Type `yes` to proceed with deletion.**

---

## Script Details

### setup-infrastructure.sh

**What it does:**
1. Validates AWS CLI and credentials
2. Creates S3 buckets with encryption and versioning
3. Creates IAM roles with proper trust policies
4. Applies bucket policies
5. Configures lifecycle rules for temp bucket
6. Creates SNS topic
7. Creates CloudWatch log groups
8. Creates n8n IAM user
9. Retrieves MediaConvert endpoint

**Important notes:**
- Script is idempotent (safe to run multiple times)
- Existing resources are skipped with warnings
- All resources are tagged with project name

**Customization:**
Edit these variables at the top of the script:
```bash
REGION="us-east-1"              # AWS region
BUCKET_PREFIX="sam-pautrat"     # S3 bucket prefix
PROJECT_NAME="video-compression-pipeline"  # Project tag
```

---

### deploy-lambdas.sh

**What it does:**
1. Validates prerequisites (Python, pip, AWS CLI)
2. Packages each Lambda function with dependencies
3. Creates or updates Lambda functions
4. Configures environment variables
5. Sets up EventBridge rule
6. Grants permissions for EventBridge to invoke Lambda

**Important notes:**
- Automatically detects if functions exist (creates or updates)
- Installs Python dependencies from requirements.txt
- Creates deployment packages in memory (cleaned up after)
- Does NOT configure Airtable credentials (manual step required)

**Function specifications:**
```
video-file-processor:   Timeout: 15 min, Memory: 512 MB
completion-handler:     Timeout: 5 min,  Memory: 256 MB
MetaDataLogger:         Timeout: 1 min,  Memory: 128 MB
```

**After running, configure Airtable:**
```bash
aws lambda update-function-configuration \
    --function-name MetaDataLogger \
    --environment 'Variables={
        AIRTABLE_BASE_ID=appXXXXXXXXXXXX,
        AIRTABLE_TABLE_NAME=Processed Videos,
        AIRTABLE_API_KEY=patXXXXXXXXXXXX
    }' \
    --region us-east-1
```

---

### cleanup.sh

**What it does:**
1. Prompts for confirmation (requires typing 'yes')
2. Deletes Lambda functions
3. Removes EventBridge rule and targets
4. Deletes CloudWatch log groups
5. Deletes SNS topic
6. Empties and deletes S3 buckets
7. Removes IAM roles and policies
8. Deletes n8n IAM user and access keys

**Important notes:**
- **DESTRUCTIVE**: Cannot be undone
- Deletes ALL files in S3 buckets
- Removes ALL access keys for n8n user
- Does NOT delete MediaConvert jobs (check manually)
- Does NOT delete Airtable base or n8n workflow

**Before running:**
- Backup any important videos from S3
- Export Airtable data if needed
- Document any custom configurations

**What to do after cleanup:**
- Manually delete Airtable base (if no longer needed)
- Remove n8n workflow
- Check for any orphaned MediaConvert jobs
- Verify SNS email unsubscription

---

## Troubleshooting

### Script fails with "command not found"

**Issue:** AWS CLI or Python not installed

**Solution:**
```bash
# Install AWS CLI (macOS)
brew install awscli

# Install AWS CLI (Linux)
pip3 install awscli --user

# Install Python 3
# macOS: brew install python3
# Ubuntu: sudo apt-get install python3 python3-pip
```

---

### Script fails with "Access Denied"

**Issue:** AWS credentials lack permissions

**Solution:**
```bash
# Verify credentials
aws sts get-caller-identity

# Ensure your IAM user has these policies:
# - IAMFullAccess (or sufficient IAM permissions)
# - AmazonS3FullAccess
# - AWSLambdaFullAccess
# - AmazonSNSFullAccess
# - CloudWatchLogsFullAccess
# - AWSElementalMediaConvertFullAccess
```

---

### "Role already exists" errors

**Issue:** Resources from previous setup still exist

**Solution:**
```bash
# Scripts are idempotent - existing resources are skipped
# This is normal and not an error
# If you want to recreate everything:
./cleanup.sh
./setup-infrastructure.sh
```

---

### Lambda deployment fails with "ValidationException"

**Issue:** IAM role not found or not ready

**Solution:**
```bash
# Wait 30 seconds and retry
sleep 30
./deploy-lambdas.sh

# Or verify role exists:
aws iam get-role --role-name LambdaExecutionRole
```

---

### S3 bucket cleanup fails

**Issue:** Bucket contains too many files or multipart uploads

**Solution:**
```bash
# Manually empty bucket
aws s3 rm s3://sam-pautrat-temp-processing --recursive

# Abort incomplete multipart uploads
aws s3api list-multipart-uploads --bucket sam-pautrat-temp-processing
# Then delete manually or wait for lifecycle rule
```

---

## Testing After Deployment

### Test infrastructure setup:
```bash
# List created resources
aws s3 ls | grep sam-pautrat
aws iam list-roles | grep -E "MediaConvert|Lambda"
aws sns list-topics | grep video-compression
aws lambda list-functions | grep -E "video|completion|metadata"
```

### Test Lambda functions:
```bash
# Test video-file-processor
cd ../../examples
aws lambda invoke \
    --function-name video-file-processor \
    --payload file://sample-event-file-processor.json \
    --cli-binary-format raw-in-base64-out \
    response.json

# View response
cat response.json

# View logs
aws logs tail /aws/lambda/video-file-processor --follow
```

---

## Best Practices

1. **Run scripts from the scripts directory:**
   ```bash
   cd aws/scripts
   ./setup-infrastructure.sh
   ```

2. **Review output carefully:**
   - Green ✓ = Success
   - Yellow ⚠ = Warning (usually okay)
   - Red ✗ = Error

3. **Save important values:**
   - MediaConvert endpoint
   - SNS topic ARN
   - n8n access keys
   - AWS Account ID

4. **Test incrementally:**
   - Run setup-infrastructure.sh
   - Verify resources in AWS Console
   - Run deploy-lambdas.sh
   - Test each Lambda function
   - Then proceed to n8n setup

5. **Keep scripts updated:**
   - If you modify bucket names, update scripts
   - If you change regions, update all scripts
   - Document any customizations

---

## Script Output Files

Scripts do not create any output files locally. All resources are created in AWS.

To save configuration details:
```bash
# Save setup output
./setup-infrastructure.sh > setup-output.txt 2>&1

# Save deployment output
./deploy-lambdas.sh > deploy-output.txt 2>&1
```

---

## Next Steps After Running Scripts

1. ✅ **Run setup-infrastructure.sh**
2. ✅ **Subscribe to SNS email** (check inbox for confirmation)
3. ✅ **Create n8n access key:**
   ```bash
   aws iam create-access-key --user-name n8n-lambda-invoker
   ```
4. ✅ **Run deploy-lambdas.sh**
5. ✅ **Configure Airtable credentials** for MetaDataLogger
6. ✅ **Test Lambda functions**
7. ✅ **Set up n8n workflow**
8. ✅ **Create Airtable base**
9. ✅ **Upload test video to Google Drive**

---

## Support

If you encounter issues:
1. Check the [Troubleshooting Guide](../../docs/TROUBLESHOOTING.md)
2. Review CloudWatch logs
3. Verify IAM permissions
4. Check AWS service quotas

For script-specific issues, run with verbose output:
```bash
bash -x ./setup-infrastructure.sh
```
