[configuration_doc.md](https://github.com/user-attachments/files/22628760/configuration_doc.md)
# Configuration Guide

Complete configuration reference for the Video Compression Pipeline.

## Table of Contents

- [AWS Configuration](#aws-configuration)
- [Lambda Environment Variables](#lambda-environment-variables)
- [MediaConvert Settings](#mediaconvert-settings)
- [n8n Workflow Configuration](#n8n-workflow-configuration)
- [Airtable Configuration](#airtable-configuration)

---

## AWS Configuration

### Required AWS Account Information

Before starting, gather these values:

```bash
# Get your AWS Account ID
aws sts get-caller-identity --query "Account" --output text

# Get your MediaConvert Endpoint
aws mediaconvert describe-endpoints --region us-east-1

# Get IAM Role ARNs
aws iam get-role --role-name MediaConvertServiceRole --query "Role.Arn"
aws iam get-role --role-name LambdaExecutionRole --query "Role.Arn"

# Get SNS Topic ARN
aws sns list-topics --query "Topics[?contains(TopicArn, 'video-compression')]"
```

### S3 Bucket Configuration

**Bucket Names:**
- Temporary processing: `sam-pautrat-temp-processing`
- Final storage: `sam-pautrat-compressed-videos`

**Bucket Policies:**

Apply these policies to enable cross-service access:

```json
// sam-pautrat-temp-processing policy
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowLambdaAndMediaConvertAccess",
            "Effect": "Allow",
            "Principal": {
                "Service": ["lambda.amazonaws.com", "mediaconvert.amazonaws.com"]
            },
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::sam-pautrat-temp-processing/*"
        }
    ]
}

// sam-pautrat-compressed-videos policy
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowMediaConvertAccess",
            "Effect": "Allow",
            "Principal": {
                "Service": "mediaconvert.amazonaws.com"
            },
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::sam-pautrat-compressed-videos/*"
        }
    ]
}
```

**Lifecycle Rules (Optional):**

```bash
# Auto-delete temp files after 7 days
aws s3api put-bucket-lifecycle-configuration \
    --bucket sam-pautrat-temp-processing \
    --lifecycle-configuration file://lifecycle-temp.json
```

---

## Lambda Environment Variables

### 1. video-file-processor

| Variable | Value | Description |
|----------|-------|-------------|
| `TEMP_BUCKET` | `sam-pautrat-temp-processing` | S3 bucket for temporary file storage |
| `COMPRESSED_BUCKET` | `sam-pautrat-compressed-videos` | S3 bucket for final compressed videos |
| `MEDIACONVERT_ROLE` | `arn:aws:iam::ACCOUNT-ID:role/MediaConvertServiceRole` | IAM role for MediaConvert |
| `SNS_TOPIC` | `arn:aws:sns:us-east-1:ACCOUNT-ID:video-compression-notifications` | SNS topic for notifications |
| `MEDIACONVERT_ENDPOINT` | `https://XXXXX.mediaconvert.us-east-1.amazonaws.com` | MediaConvert endpoint URL |

**Setting via AWS CLI:**

```bash
aws lambda update-function-configuration \
    --function-name video-file-processor \
    --environment Variables='{
        "TEMP_BUCKET":"sam-pautrat-temp-processing",
        "COMPRESSED_BUCKET":"sam-pautrat-compressed-videos",
        "MEDIACONVERT_ROLE":"arn:aws:iam::123456789012:role/MediaConvertServiceRole",
        "SNS_TOPIC":"arn:aws:sns:us-east-1:123456789012:video-compression-notifications",
        "MEDIACONVERT_ENDPOINT":"https://abc123.mediaconvert.us-east-1.amazonaws.com"
    }' \
    --region us-east-1
```

### 2. completion-handler

All variables from `video-file-processor` PLUS:

| Variable | Value | Description |
|----------|-------|-------------|
| `METADATA_LOGGER_FUNCTION` | `MetaDataLogger` | Name of metadata logger Lambda function |

**Setting via AWS CLI:**

```bash
aws lambda update-function-configuration \
    --function-name completion-handler \
    --environment Variables='{
        "TEMP_BUCKET":"sam-pautrat-temp-processing",
        "COMPRESSED_BUCKET":"sam-pautrat-compressed-videos",
        "MEDIACONVERT_ROLE":"arn:aws:iam::123456789012:role/MediaConvertServiceRole",
        "SNS_TOPIC":"arn:aws:sns:us-east-1:123456789012:video-compression-notifications",
        "MEDIACONVERT_ENDPOINT":"https://abc123.mediaconvert.us-east-1.amazonaws.com",
        "METADATA_LOGGER_FUNCTION":"MetaDataLogger"
    }' \
    --region us-east-1
```

### 3. MetaDataLogger

| Variable | Value | Description |
|----------|-------|-------------|
| `AIRTABLE_BASE_ID` | `appXXXXXXXXXXXXXX` | Airtable base identifier |
| `AIRTABLE_TABLE_NAME` | `Processed Videos` | Name of Airtable table |
| `AIRTABLE_API_KEY` | `patXXXXXXXXXXXXXX` | Personal Access Token for Airtable API |

**Setting via AWS CLI:**

```bash
aws lambda update-function-configuration \
    --function-name MetaDataLogger \
    --environment Variables='{
        "AIRTABLE_BASE_ID":"appABC123DEF456",
        "AIRTABLE_TABLE_NAME":"Processed Videos",
        "AIRTABLE_API_KEY":"patXYZ789ABC123"
    }' \
    --region us-east-1
```

---

## MediaConvert Settings

### Job Template Configuration

**Current Settings (High Quality 720p):**

```json
{
    "VideoDescription": {
        "Width": 1280,
        "Height": 720,
        "CodecSettings": {
            "Codec": "H_264",
            "H264Settings": {
                "RateControlMode": "QVBR",
                "QvbrSettings": {
                    "QvbrQualityLevel": 8
                },
                "MaxBitrate": 5000000,
                "QualityTuningLevel": "MULTI_PASS_HQ",
                "SceneChangeDetect": "ENABLED"
            }
        }
    },
    "AudioDescriptions": [{
        "CodecSettings": {
            "Codec": "AAC",
            "AacSettings": {
                "Bitrate": 128000,
                "SampleRate": 48000,
                "CodecProfile": "LC"
            }
        }
    }]
}
```

### Quality Levels

Adjust `QvbrQualityLevel` for different quality/size trade-offs:

| Level | Quality | File Size | Use Case |
|-------|---------|-----------|----------|
| 10 | Maximum | Largest | Archival, master copies |
| 8 | High (Current) | Large | Dubbing, professional use |
| 7 | Good | Medium | Streaming, web delivery |
| 5 | Acceptable | Small | Low-bandwidth scenarios |

### Resolution Presets

**720p (Current):**
```json
{"Width": 1280, "Height": 720}
```

**1080p:**
```json
{"Width": 1920, "Height": 1080}
```

**4K:**
```json
{"Width": 3840, "Height": 2160}
```

### Bitrate Guidelines

| Resolution | Recommended Max Bitrate |
|------------|------------------------|
| 720p | 5 Mbps |
| 1080p | 8 Mbps |
| 4K | 20 Mbps |

---

## n8n Workflow Configuration

### Google Drive Trigger Configuration

```json
{
  "name": "Google Drive Trigger",
  "type": "googleDriveTrigger",
  "parameters": {
    "event": "fileCreated",
    "folderId": "YOUR_FOLDER_ID",
    "options": {
      "fileExtensions": "mp4"
    }
  }
}
```

### AWS Lambda Node Configuration

```json
{
  "name": "AWS Lambda",
  "type": "awsLambda",
  "parameters": {
    "operation": "invoke",
    "functionName": "video-file-processor",
    "invocationType": "RequestResponse",
    "payload": {
      "body": "={\"fileUrl\":\"{{ $json.webViewLink }}\",\"fileName\":\"{{ $json.name }}\",\"fileSize\":{{ $json.size }},\"uploader\":\"{{ $json.owners[0].emailAddress }}\"}"
    }
  },
  "credentials": {
    "aws": {
      "id": "YOUR_AWS_CREDENTIAL_ID",
      "name": "AWS account"
    }
  }
}
