# n8n Workflow Configuration

This directory contains the n8n workflow configuration for the Video Compression Pipeline.

## Overview

The n8n workflow automates the detection of new video files uploaded to Google Drive and triggers the AWS Lambda processing pipeline.

## Workflow Flow

```
Google Drive Upload
    ↓
Google Drive Trigger (Webhook)
    ↓
Validate File (Check type & size)
    ↓
Prepare Lambda Payload (Format data)
    ↓
Invoke Lambda (Call video-file-processor)
    ↓
Check Lambda Response (Success/Error)
    ↓
Format Response
```

---

## Prerequisites

Before setting up the workflow, ensure you have:

- [x] n8n Cloud account (or self-hosted n8n instance)
- [x] Google account with Google Drive access
- [x] AWS account with Lambda functions deployed
- [x] AWS IAM user credentials for n8n (created during setup)

---

## Setup Instructions

### Step 1: Create n8n Cloud Account

1. Go to [n8n.cloud](https://n8n.cloud)
2. Sign up for an account
3. Verify your email
4. Log in to your n8n dashboard

### Step 2: Import Workflow

#### Option A: Import via UI

1. Log in to n8n Cloud
2. Click **"New Workflow"** or **"+"** button
3. Click **"⋮"** (three dots) → **"Import from File"**
4. Select `workflow.json` from this directory
5. Click **"Import"**

#### Option B: Copy-Paste JSON

1. Open `workflow.json` in a text editor
2. Copy the entire contents
3. In n8n, click **"New Workflow"**
4. Click **"⋮"** → **"Import from URL or File"** → **"Paste JSON"**
5. Paste the workflow JSON
6. Click **"Import"**

### Step 3: Configure Google Drive Credentials

1. Click on the **"Google Drive Trigger"** node
2. Click **"Credential for Google Drive API"** dropdown
3. Click **"Create New Credential"**
4. Select **"Google Drive OAuth2 API"**
5. Click **"Connect my account"** or **"Sign in with Google"**
6. Authenticate with your Google account
7. Grant n8n access to Google Drive
8. Click **"Save"**

**Select Target Folder:**
1. In the Google Drive Trigger node
2. Under **"Folder to Watch"**
3. Click **"Select folder from list"**
4. Choose the folder where videos will be uploaded
5. Save the workflow

### Step 4: Configure AWS Credentials

1. Click on the **"Invoke Lambda"** node
2. Click **"Credential for AWS"** dropdown
3. Click **"Create New Credential"**
4. Select **"AWS"**
5. Enter your credentials:
   - **Access Key ID**: From n8n IAM user (created during AWS setup)
   - **Secret Access Key**: From n8n IAM user
   - **Region**: `us-east-1` (or your chosen region)
6. Click **"Save"**

**To get AWS credentials for n8n:**
```bash
# This was created during infrastructure setup
aws iam create-access-key --user-name n8n-lambda-invoker
```

Save the `AccessKeyId` and `SecretAccessKey` from the output.

### Step 5: Update Lambda Function Name

1. In the **"Invoke Lambda"** node
2. Verify **"Function Name"** is set to: `video-file-processor`
3. Verify **"Invocation Type"** is: `RequestResponse`
4. Save the workflow

### Step 6: Activate Workflow

1. Click the **"Active"** toggle at the top of the workflow
2. The workflow is now listening for new files in Google Drive

---

## Workflow Nodes Explained

### 1. Google Drive Trigger

**Purpose:** Detects new files uploaded to Google Drive

**Configuration:**
- **Event:** File Created
- **Trigger On:** Specific Folder
- **Folder:** Your chosen Google Drive folder
- **File Extensions:** mp4, mov, avi, mkv

**Output:** File metadata including name, size, URL, uploader

### 2. Validate File

**Purpose:** Ensures file meets processing criteria

**Validation Checks:**
- File MIME type contains "video"
- File size is greater than 1 MB

**Output:** 
- True path → Continue to processing
- False path → Skip file (ends workflow)

### 3. Prepare Lambda Payload

**Purpose:** Formats file metadata for Lambda function

**Extracts:**
- File name
- File size (bytes)
- File URL (Google Drive)
- Uploader email
- MIME type
- Created time

**Output:** JSON object ready for Lambda invocation

### 4. Invoke Lambda

**Purpose:** Calls AWS Lambda function to start processing

**Configuration:**
- **Function:** video-file-processor
- **Type:** RequestResponse (synchronous)
- **Retry:** Enabled (2 attempts, 10 second delay)

**Payload Format:**
```json
{
  "body": "{\"fileUrl\":\"...\",\"fileName\":\"...\",\"fileSize\":...,\"uploader\":\"...\"}"
}
```

**Output:** Lambda response with status code and result

### 5. Check Lambda Response

**Purpose:** Determines if Lambda invocation succeeded

**Checks:** Status code equals 200

**Output:**
- Success path → Format success response
- Error path → Format error response

### 6. Format Success/Error Response

**Purpose:** Parses Lambda response and formats for logging

**Success Response:**
```json
{
  "success": true,
  "statusCode": 200,
  "message": "File processing started",
  "jobId": "1234567890",
  "fileName": "video.mp4",
  "originalSize": 1234567890,
  "timestamp": "2024-01-15T10:00:00.000Z"
}
```

**Error Response:**
```json
{
  "success": false,
  "statusCode": 500,
  "error": "Error message",
  "timestamp": "2024-01-15T10:00:00.000Z"
}
```

---

## Testing the Workflow

### Test with a Sample File

1. **Prepare a test video file:**
   - Size: 100 MB - 1 GB (for quick testing)
   - Format: MP4
   - Name: `test-video.mp4`

2. **Upload to Google Drive:**
   - Upload to the folder you configured in the trigger
   - Wait 10-30 seconds for webhook to fire

3. **Check n8n Execution:**
   - Go to **"Executions"** tab in n8n
   - You should see a new execution
   - Click on it to view details
   - Verify all nodes executed successfully

4. **Check AWS:**
   ```bash
   # Check Lambda logs
   aws logs tail /aws/lambda/video-file-processor --follow
   
   # Check MediaConvert jobs
   aws mediaconvert list-jobs --max-results 5 \
       --endpoint-url https://YOUR-ENDPOINT.mediaconvert.us-east-1.amazonaws.com
   ```

5. **Check Email:**
   - You should receive an SNS notification
   - Subject: "Video Processing Started: test-video.mp4"

### Manual Test (Without Upload)

1. In n8n, click **"Test Workflow"** button
2. Click **"Execute Node"** on the "Invoke Lambda" node
3. Manually provide test data:
   ```json
   {
     "fileUrl": "https://drive.google.com/file/d/TEST/view",
     "fileName": "test.mp4",
     "fileSize": 1000000000,
     "uploader": "test@example.com"
   }
   ```

---

## Troubleshooting

### Workflow Not Triggering

**Issue:** Upload file to Drive but workflow doesn't execute

**Solutions:**

1. **Check workflow is active:**
   - Toggle should be green/on
   - If gray, click to activate

2. **Verify Google Drive connection:**
   - Click Google Drive Trigger node
   - Click "Test step"
   - Should list files from your folder
   - If error, reconnect Google account

3. **Check webhook status:**
   - Google Drive Trigger should show "Listening"
   - If not, deactivate and reactivate workflow

4. **Verify folder access:**
   - Ensure folder is not in Shared Drive (different setup needed)
   - Check file permissions

### Lambda Invocation Fails

**Issue:** Error when invoking Lambda function

**Solutions:**

1. **Verify AWS credentials:**
   ```bash
   # Test credentials
   aws lambda list-functions --region us-east-1
   ```

2. **Check IAM permissions:**
   ```bash
   aws iam get-user-policy \
       --user-name n8n-lambda-invoker \
       --policy-name LambdaInvokePolicy
   ```

3. **Verify function name:**
   - Must be exactly: `video-file-processor`
   - Check in AWS Console or CLI:
     ```bash
     aws lambda get-function --function-name video-file-processor
     ```

4. **Check region:**
   - Ensure AWS credential region matches Lambda region
   - Default: us-east-1

### Invalid Payload Error

**Issue:** Lambda receives malformed payload

**Solutions:**

1. **Check payload format in Invoke Lambda node:**
   - Should be a JSON string wrapped in `body` key
   - Verify double escaping of quotes

2. **Test payload manually:**
   ```bash
   aws lambda invoke \
       --function-name video-file-processor \
       --payload '{"fileUrl":"...","fileName":"test.mp4","fileSize":1000000,"uploader":"test@test.com"}' \
       response.json
   ```

### File Validation Fails

**Issue:** All files are being skipped

**Solutions:**

1. **Check validation conditions:**
   - MIME type must contain "video"
   - File size must be > 1 MB

2. **Test with known good file:**
   - Upload a standard MP4 file
   - Size: 10-100 MB

3. **Debug validation node:**
   - Click "Execute Node" on Validate File
   - Check input data
   - Verify conditions match

---

## Customization

### Change Supported File Types

Edit Google Drive Trigger node:
```
File Extensions: mp4,mov,avi,mkv,flv,wmv,webm
```

### Adjust File Size Validation

Edit Validate File node conditions:
```javascript
// Minimum 10 MB instead of 1 MB
{{$json["size"]}} larger than 10000000

// Maximum 20 GB
{{$json["size"]}} smaller than 20000000000
```

### Add Notification Node

Add an HTTP Request or Email node after success:

1. Add **"HTTP Request"** node after Format Success Response
2. Configure to call your webhook or API
3. Send notification to Slack, Discord, etc.

### Add Error Alerting

Add email notification on error:

1. Add **"Send Email"** node after Format Error Response
2. Configure SMTP settings
3. Send alert when Lambda fails

---

## Workflow Maintenance

### Monitor Executions

1. Go to **"Executions"** tab in n8n
2. Filter by:
   - Status (Success/Error)
   - Date range
   - Workflow name

3. Review failed executions:
   - Click on failed execution
   - Check error message
   - Retry if needed

### Update Workflow

1. Deactivate workflow (toggle off)
2. Make changes to nodes
3. Click **"Save"**
4. Test with sample data
5. Reactivate workflow (toggle on)

### Export Workflow

To backup or share:

1. Click **"⋮"** (three dots)
2. Click **"Download"**
3. Save as `workflow-backup.json`

---

## Performance Tips

1. **Selective Folder Monitoring:**
   - Monitor specific folder, not entire Drive
   - Reduces webhook traffic

2. **File Type Filtering:**
   - Specify extensions in trigger
   - Reduces unnecessary executions

3. **Validation Early:**
   - Filter invalid files before Lambda invocation
   - Saves Lambda costs

4. **Error Handling:**
   - Enable retry on Lambda node
   - Set appropriate retry delay

---

## Security Best Practices

1. **AWS Credentials:**
   - Use dedicated IAM user for n8n
   - Grant minimum required permissions
   - Rotate access keys periodically

2. **Google OAuth:**
   - Only grant necessary Drive permissions
   - Review connected apps regularly
   - Revoke access if no longer needed

3. **Workflow Access:**
   - Don't share workflow with sensitive credentials
   - Use n8n's environment variables for secrets
   - Review workflow sharing settings

---

## Advanced Configuration

### Use n8n Environment Variables

Instead of hardcoding AWS region:

1. Go to n8n Settings → Variables
2. Add: `AWS_REGION=us-east-1`
3. In workflow, use: `={{$env.AWS_REGION}}`

### Add Conditional Logic

Process files differently based on size:

```javascript
// In a Code node
const fileSizeGB = $input.item.json.fileSize / (1024*1024*1024);

if (fileSizeGB > 10) {
  // Large file - different processing
  return {json: {priority: 'high'}};
} else {
  // Normal file
  return {json: {priority: 'normal'}};
}
```

### Batch Processing

Process multiple files in a single execution:

1. Change trigger to polling mode (check folder periodically)
2. Add **"Split In Batches"** node
3. Process files in groups

---

## Support Resources

- **n8n Documentation:** https://docs.n8n.io
- **n8n Community Forum:** https://community.n8n.io
- **Google Drive API Docs:** https://developers.google.com/drive
- **AWS Lambda Docs:** https://docs.aws.amazon.com/lambda

---

## Next Steps

After workflow is set up and tested:

1. ✅ Upload test video to Google Drive
2. ✅ Verify workflow executes successfully
3. ✅ Check Lambda CloudWatch logs
4. ✅ Confirm MediaConvert job starts
5. ✅ Wait for completion email from SNS
6. ✅ Verify compressed video in S3
7. ✅ Check Airtable record created
8. ✅ Process production videos

---

## Workflow Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-01-15 | Initial workflow creation |

---

For issues or questions, refer to the main [Troubleshooting Guide](../docs/TROUBLESHOOTING.md).
