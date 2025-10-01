# Troubleshooting Guide

## Table of Contents

- [General Debugging](#general-debugging)
- [Lambda Function Issues](#lambda-function-issues)
- [MediaConvert Issues](#mediaconvert-issues)
- [n8n Workflow Issues](#n8n-workflow-issues)
- [S3 Storage Issues](#s3-storage-issues)
- [Airtable Issues](#airtable-issues)
- [Notification Issues](#notification-issues)
- [Performance Issues](#performance-issues)

---

## General Debugging

### Check Overall Pipeline Status

```bash
# Check Lambda function status
aws lambda list-functions --query "Functions[?contains(FunctionName, 'video')].{Name:FunctionName,Status:State}" --output table

# Check recent Lambda executions
aws lambda get-function --function-name video-file-processor
aws lambda get-function --function-name completion-handler
aws lambda get-function --function-name MetaDataLogger

# Check CloudWatch logs (last 10 minutes)
aws logs tail /aws/lambda/video-file-processor --since 10m
aws logs tail /aws/lambda/completion-handler --since 10m
aws logs tail /aws/lambda/MetaDataLogger --since 10m

# Check MediaConvert jobs
aws mediaconvert list-jobs --max-results 10 --endpoint-url https://YOUR-ENDPOINT.mediaconvert.us-east-1.amazonaws.com
```

### Common Diagnostic Commands

```bash
# Get AWS Account ID
aws sts get-caller-identity

# List S3 buckets
aws s3 ls | grep sam-pautrat

# Check SNS topic
aws sns list-topics | grep video-compression

# Check EventBridge rules
aws events list-rules | grep MediaConvert

# Check IAM roles
aws iam get-role --role-name MediaConvertServiceRole
aws iam get-role --role-name LambdaExecutionRole
```

---

## Lambda Function Issues

### Issue 1: Lambda Function Timeout

**Symptoms**:
- Function execution exceeds configured timeout
- Error: "Task timed out after X seconds"

**Causes**:
- Large file downloads taking too long
- MediaConvert API calls hanging
- Network latency

**Solutions**:

```bash
# Increase timeout (max 15 minutes)
aws lambda update-function-configuration \
    --function-name video-file-processor \
    --timeout 900

# Increase memory (improves CPU allocation)
aws lambda update-function-configuration \
    --function-name video-file-processor \
    --memory-size 1024
```

**Prevention**:
- Monitor CloudWatch metrics for execution duration
- Set CloudWatch alarms for timeouts

### Issue 2: Out of Memory Error

**Symptoms**:
- Error: "Process exited before completing request"
- No clear error message in logs

**Causes**:
- Large file processing in memory
- Insufficient memory allocation

**Solutions**:

```bash
# Increase memory allocation
aws lambda update-function-configuration \
    --function-name video-file-processor \
    --memory-size 1024

# For very large files, use streaming instead of loading entire file
```

**Code fix** (in lambda_function.py):
```python
# Instead of reading entire file
response = requests.get(url).content

# Use streaming
response = requests.get(url, stream=True)
for chunk in response.iter_content(chunk_size=8192):
    # Process chunk
```

### Issue 3: Environment Variables Not Found

**Symptoms**:
- Error: "KeyError: 'VARIABLE_NAME'"
- Default placeholder values being used

**Solutions**:

```bash
# Check current environment variables
aws lambda get-function-configuration \
    --function-name video-file-processor \
    --query 'Environment'

# Update environment variables
aws lambda update-function-configuration \
    --function-name video-file-processor \
    --environment Variables='{
        "TEMP_BUCKET":"sam-pautrat-temp-processing",
        "COMPRESSED_BUCKET":"sam-pautrat-compressed-videos"
    }'
```

### Issue 4: Permission Denied Errors

**Symptoms**:
- Error: "Access Denied" or "403 Forbidden"
- Cannot write to S3, invoke Lambda, or publish to SNS

**Solutions**:

```bash
# Check IAM role policies
aws iam get-role-policy \
    --role-name LambdaExecutionRole \
    --policy-name LambdaExecutionPolicy

# Attach missing permissions
aws iam put-role-policy \
    --role-name LambdaExecutionRole \
    --policy-name S3Access \
    --policy-document file://s3-policy.json
```

**Verify permissions**:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::sam-pautrat-*/*"
            ]
        }
    ]
}
```

### Issue 5: Lambda Not Triggered

**Symptoms**:
- n8n shows success but Lambda doesn't execute
- No CloudWatch logs for the function

**Solutions**:

```bash
# Check Lambda permissions for n8n
aws lambda get-policy --function-name video-file-processor

# Verify n8n can invoke Lambda
aws lambda invoke \
    --function-name video-file-processor \
    --payload file://test-event.json \
    --cli-binary-format raw-in-base64-out \
    response.json

# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --dimensions Name=FunctionName,Value=video-file-processor \
    --start-time 2024-01-15T00:00:00Z \
    --end-time 2024-01-15T23:59:59Z \
    --period 3600 \
    --statistics Sum
```

---

## MediaConvert Issues

### Issue 1: Job Fails to Start

**Symptoms**:
- Error: "Unable to create job"
- Job never appears in MediaConvert console

**Causes**:
- Invalid IAM role
- Incorrect endpoint URL
- Invalid input file path

**Solutions**:

```bash
# Verify MediaConvert endpoint
aws mediaconvert describe-endpoints --region us-east-1

# Test MediaConvert access
aws mediaconvert list-jobs \
    --max-results 1 \
    --endpoint-url https://YOUR-ENDPOINT.mediaconvert.us-east-1.amazonaws.com

# Check IAM role permissions
aws iam simulate-principal-policy \
    --policy-source-arn arn:aws:iam::ACCOUNT-ID:role/MediaConvertServiceRole \
    --action-names s3:GetObject s3:PutObject \
    --resource-arns arn:aws:s3:::sam-pautrat-temp-processing/*
```

**Verify input file exists**:
```bash
aws s3 ls s3://sam-pautrat-temp-processing/temp/
```

### Issue 2: Job Fails During Processing

**Symptoms**:
- Job status: ERROR
- Error code: 1404 or similar

**Common Error Codes**:
- **1404**: Input file not found or inaccessible
- **1201**: Invalid video format
- **3002**: Output location not accessible

**Solutions**:

```bash
# Get detailed job error
aws mediaconvert get-job \
    --id JOB-ID \
    --endpoint-url https://YOUR-ENDPOINT.mediaconvert.us-east-1.amazonaws.com \
    --query 'Job.ErrorMessage'

# Check input file
aws s3 cp s3://sam-pautrat-temp-processing/temp/FILE.mp4 test.mp4

# Verify file is valid video
ffprobe test.mp4
```

**Input format issues**:
- Ensure file is actually MP4 (check extension and actual format)
- Some codecs not supported - convert to H.264 first
- Corrupted files will fail

### Issue 3: Poor Quality Output

**Symptoms**:
- Compressed video quality is unacceptable
- Video is blurry or pixelated

**Solutions**:

Adjust QVBR quality level:
```python
# In video-file-processor lambda_function.py
"QvbrSettings": {
    "QvbrQualityLevel": 9  # Increase from 8 to 9 or 10
}
```

Increase bitrate:
```python
"MaxBitrate": 8000000  # Increase from 5000000
```

Change resolution:
```python
"Width": 1920,   # From 1280
"Height": 1080,  # From 720
```

### Issue 4: Processing Takes Too Long

**Symptoms**:
- Jobs take hours to complete
- Timeout concerns

**Solutions**:

```bash
# Use faster quality preset
"QualityTuningLevel": "SINGLE_PASS"  # Instead of "MULTI_PASS_HQ"

# Or use on-demand queue with priority
--queue arn:aws:mediaconvert:us-east-1:ACCOUNT-ID:queues/Default
--priority 10  # Higher priority
```

---

## n8n Workflow Issues

### Issue 1: Google Drive Trigger Not Firing

**Symptoms**:
- Upload file to Drive but workflow doesn't trigger
- No new executions in n8n

**Solutions**:

1. **Check webhook status** in n8n:
   - Go to workflow → Google Drive Trigger node
   - Verify "Listening" status is active

2. **Reauthorize Google Drive**:
   - Delete existing Google Drive credential
   - Create new credential
   - Reconnect account

3. **Check Google Drive permissions**:
   - Ensure n8n has access to the folder
   - Verify folder isn't in shared drive (may need different setup)

4. **Test manually**:
   - Click "Execute Node" in n8n
   - Upload a test file
   - Check if detection works

### Issue 2: AWS Lambda Node Fails

**Symptoms**:
- Error: "AccessDenied" or "InvalidSignature"
- Lambda not invoked from n8n

**Solutions**:

1. **Verify AWS credentials in n8n**:
   ```
   Access Key ID: Should start with AKIA...
   Secret Access Key: Check for typos
   Region: us-east-1
   ```

2. **Test IAM user permissions**:
   ```bash
   # Using the n8n IAM user credentials
   aws lambda invoke \
       --function-name video-file-processor \
       --payload '{"test":true}' \
       --cli-binary-format raw-in-base64-out \
       response.json
   ```

3. **Check IAM policy**:
   ```bash
   aws iam list-user-policies --user-name n8n-lambda-invoker
   aws iam get-user-policy \
       --user-name n8n-lambda-invoker \
       --policy-name LambdaInvokePolicy
   ```

### Issue 3: Payload Format Error

**Symptoms**:
- Lambda receives event but can't parse it
- Error: "Invalid event format"

**Solutions**:

Verify n8n Lambda node payload:
```json
{
  "body": "={\"fileUrl\":\"{{ $json.webViewLink }}\",\"fileName\":\"{{ $json.name }}\",\"fileSize\":{{ $json.size }},\"uploader\":\"{{ $json.owners[0].emailAddress }}\"}"
}
```

Test with static payload first:
```json
{
  "body": "{\"fileUrl\":\"https://drive.google.com/file/d/TEST/view\",\"fileName\":\"test.mp4\",\"fileSize\":1000000,\"uploader\":\"test@example.com\"}"
}
```

---

## S3 Storage Issues

### Issue 1: Upload Fails

**Symptoms**:
- Error: "Access Denied" when uploading to S3
- Cannot write files to bucket

**Solutions**:

```bash
# Check bucket policy
aws s3api get-bucket-policy --bucket sam-pautrat-temp-processing

# Verify Lambda has write permissions
aws iam get-role-policy \
    --role-name LambdaExecutionRole \
    --policy-name LambdaExecutionPolicy \
    --query 'PolicyDocument.Statement[?Effect==`Allow`]'

# Test write access
aws s3 cp test.txt s3://sam-pautrat-temp-processing/test/
```

### Issue 2: File Not Found

**Symptoms**:
- MediaConvert can't find input file
- Error: "The specified key does not exist"

**Solutions**:

```bash
# List files in temp bucket
aws s3 ls s3://sam-pautrat-temp-processing/temp/ --recursive

# Check file exists
aws s3api head-object \
    --bucket sam-pautrat-temp-processing \
    --key temp/FILE.mp4

# Verify path in MediaConvert job
# Should be: s3://bucket-name/key
# NOT: s3://bucket-name//key (double slash)
```

### Issue 3: Storage Costs Too High

**Symptoms**:
- Unexpected S3 charges
- Temp files not being deleted

**Solutions**:

```bash
# Check total storage
aws s3 ls s3://sam-pautrat-temp-processing --recursive --summarize

# Set up lifecycle rule
aws s3api put-bucket-lifecycle-configuration \
    --bucket sam-pautrat-temp-processing \
    --lifecycle-configuration file://lifecycle.json
```

**lifecycle.json**:
```json
{
    "Rules": [{
        "Id": "DeleteTempFiles",
        "Status": "Enabled",
        "Prefix": "temp/",
        "Expiration": {
            "Days": 7
        }
    }]
}
```

---

## Airtable Issues

### Issue 1: Authentication Fails

**Symptoms**:
- Error: "401 Unauthorized"
- Records not being created

**Solutions**:

1. **Verify Personal Access Token**:
   - Go to https://airtable.com/create/tokens
   - Check token hasn't expired
   - Verify scopes include `data.records:read` and `data.records:write`

2. **Test API connection**:
```bash
curl -X GET "https://api.airtable.com/v0/YOUR-BASE-ID/Processed%20Videos" \
    -H "Authorization: Bearer YOUR-PAT"
```

3. **Update Lambda environment variable**:
```bash
aws lambda update-function-configuration \
    --function-name MetaDataLogger \
    --environment Variables='{"AIRTABLE_API_KEY":"patNEW_TOKEN"}'
```

### Issue 2: Field Validation Errors

**Symptoms**:
- Error: "422 Unprocessable Entity"
- Message: "Unknown field name"

**Causes**:
- Field names don't match exactly (case-sensitive)
- Field type mismatch

**Solutions**:

1. **Verify field names**:
   - Go to Airtable base
   - Compare field names exactly
   - Check for extra spaces

2. **Common mismatches**:
   ```python
   # Wrong
   "Original Size": 1000  # Number sent to text field
   
   # Correct
   "Original Size (MB)": 1000.5  # Number to number field
   ```

### Issue 3: Base ID Not Found

**Symptoms**:
- Error: "404 Not Found"
- Error: "Could not find table"

**Solutions**:

```bash
# Get correct Base ID
# Go to https://airtable.com/api
# Click your base
# Copy ID from URL (starts with 'app')

# Verify table name
# Must match exactly: "Processed Videos"
# NOT: "processed videos" or "ProcessedVideos"
```

### Issue 4: Rate Limit Exceeded

**Symptoms**:
- Error: "429 Too Many Requests"
- Intermittent failures

**Solutions**:

Add retry logic in lambda_function.py:
```python
import time
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry

session = requests.Session()
retry = Retry(
    total=3,
    backoff_factor=1,
    status_forcelist=[429, 500, 502, 503, 504]
)
adapter = HTTPAdapter(max_retries=retry)
session.mount('https://', adapter)
```

---

## Notification Issues

### Issue 1: Not Receiving Emails

**Symptoms**:
- No SNS notifications received
- Processing completes but no email

**Solutions**:

1. **Check SNS subscription**:
```bash
aws sns list-subscriptions-by-topic \
    --topic-arn arn:aws:sns:us-east-1:ACCOUNT-ID:video-compression-notifications

# Look for your email with "SubscriptionArn"
# If "PendingConfirmation", check spam folder
```

2. **Resubscribe email**:
```bash
aws sns subscribe \
    --topic-arn arn:aws:sns:us-east-1:ACCOUNT-ID:video-compression-notifications \
    --protocol email \
    --notification-endpoint your-email@example.com
```

3. **Check spam folder**:
   - Look for AWS notification confirmation
   - Add no-reply@sns.amazonaws.com to contacts

### Issue 2: Duplicate Notifications

**Symptoms**:
- Receiving multiple emails for same job
- Lambda invoked multiple times

**Causes**:
- EventBridge rule triggering multiple times
- Retry logic issues

**Solutions**:

```bash
# Check EventBridge targets
aws events list-targets-by-rule \
    --rule MediaConvertJobStateChange

# Should only have one target (completion-handler)
# If duplicates, remove extras:
aws events remove-targets \
    --rule MediaConvertJobStateChange \
    --ids "2"
```

### Issue 3: Email Content Malformed

**Symptoms**:
- Email received but content is JSON or unreadable
- Missing information

**Solutions**:

Update SNS message format in lambda:
```python
# Format the message nicely
message = f"""
Video Compression Complete!

File: {file_name}
Original Size: {original_size_mb:.2f} MB
Compressed Size: {compressed_size_mb:.2f} MB
Compression Ratio: {compression_ratio:.2f}:1
Processing Time: {processing_time:.1f} minutes

Download: {compressed_url}
"""

sns_client.publish(
    TopicArn=SNS_TOPIC,
    Message=message,
    Subject=f"Video Compression Complete: {file_name}"
)
```

---

## Performance Issues

### Issue 1: Slow File Downloads

**Symptoms**:
- Lambda timeout during Google Drive download
- Takes minutes to download small files

**Solutions**:

1. **Increase Lambda memory** (improves network throughput):
```bash
aws lambda update-function-configuration \
    --function-name video-file-processor \
    --memory-size 1024
```

2. **Use streaming download**:
```python
# Instead of downloading entire file
response = urllib.request.urlopen(url)
data = response.read()

# Use streaming with chunks
with urllib.request.urlopen(url) as response:
    while True:
        chunk = response.read(8192)
        if not chunk:
            break
        # Process chunk
```

3. **Check Google Drive API limits**:
   - Might be rate limited
   - Consider using Google Drive API directly instead of webhook

### Issue 2: MediaConvert Queue Backlog

**Symptoms**:
- Jobs sit in queue for long time
- Status: SUBMITTED for extended period

**Solutions**:

```bash
# Check queue status
aws mediaconvert get-queue \
    --name Default \
    --endpoint-url https://YOUR-ENDPOINT.mediaconvert.us-east-1.amazonaws.com

# Create dedicated queue with reserved capacity
aws mediaconvert create-queue \
    --name HighPriority \
    --pricing-plan RESERVED \
    --endpoint-url https://YOUR-ENDPOINT.mediaconvert.us-east-1.amazonaws.com
```

### Issue 3: Airtable Updates Slow

**Symptoms**:
- Delay between completion and Airtable record
- MetaDataLogger takes long time

**Solutions**:

1. **Check CloudWatch logs**:
```bash
aws logs tail /aws/lambda/MetaDataLogger --since 30m
```

2. **Increase timeout**:
```bash
aws lambda update-function-configuration \
    --function-name MetaDataLogger \
    --timeout 120
```

3. **Verify Airtable API response time**:
```python
import time
start = time.time()
response = requests.post(AIRTABLE_URL, ...)
duration = time.time() - start
logger.info(f"Airtable API took {duration:.2f}s")
```

---

## Getting Help

### Log Analysis

**Enable detailed logging**:
```python
import logging
logger.setLevel(logging.DEBUG)
```

**View logs in real-time**:
```bash
aws logs tail /aws/lambda/FUNCTION-NAME --follow --format short
```

### Support Resources

1. **AWS Support**: https://console.aws.amazon.com/support
2. **MediaConvert Documentation**: https://docs.aws.amazon.com/mediaconvert
3. **Lambda Troubleshooting**: https://docs.aws.amazon.com/lambda/latest/dg/lambda-troubleshooting.html
4. **Airtable API Docs**: https://airtable.com/api
5. **n8n Community**: https://community.n8n.io

### Create Support Ticket

Include:
- CloudWatch log excerpts
- Function configuration
- Test event that reproduces issue
- Error messages
- Timeline of events

### Emergency Contacts

- AWS: Create support case in console
- Airtable: support@airtable.com
- n8n: community.n8n.io

---

## Preventive Measures

### Monitoring Setup

```bash
# Create CloudWatch alarm for errors
aws cloudwatch put-metric-alarm \
    --alarm-name video-processor-errors \
    --alarm-description "Alert on Lambda errors" \
    --metric-name Errors \
    --namespace AWS/Lambda \
    --statistic Sum \
    --period 300 \
    --threshold 5 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=FunctionName,Value=video-file-processor \
    --evaluation-periods 1 \
    --alarm-actions arn:aws:sns:us-east-1:ACCOUNT-ID:video-compression-notifications
```

### Regular Maintenance

- Review CloudWatch logs weekly
- Check S3 storage usage monthly
- Verify SNS subscriptions quarterly
- Update Lambda runtimes when new versions available
- Rotate API keys annually
