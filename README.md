
# Video Compression Automation Pipeline

[![AWS](https://img.shields.io/badge/AWS-Lambda%20%7C%20S3%20%7C%20MediaConvert-orange)](https://aws.amazon.com/)
[![Python](https://img.shields.io/badge/Python-3.9+-blue)](https://www.python.org/)
[![n8n](https://img.shields.io/badge/n8n-Workflow%20Automation-red)](https://n8n.io/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **Serverless video compression pipeline for dubbing workflows** - Automatically compress large video files while maintaining 720p+ quality, with complete metadata tracking and notifications.

## 🎯 Project Overview

An enterprise-grade, serverless video compression pipeline designed for dubbing studios and content creators who need to process large video files efficiently. The system automatically detects new uploads, compresses videos to under 5GB while maintaining quality, and tracks all processing metadata.

### Key Features

- ✅ **Automated Workflow** - Zero manual intervention from upload to completion
- ✅ **Quality Preservation** - Maintains minimum 720p resolution (non-negotiable)
- ✅ **Smart Compression** - Only compresses files > 5GB
- ✅ **Real-time Notifications** - Email alerts at every stage
- ✅ **Metadata Tracking** - Complete audit trail in Airtable
- ✅ **Error Handling** - Automatic retries with failure logging
- ✅ **Scalable Architecture** - Handles 100-150 files per day
- ✅ **Cost Optimized** - Serverless architecture with pay-per-use pricing

---

## 📋 Table of Contents

- [Architecture](#-architecture)
- [Technology Stack](#-technology-stack)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
  - [AWS Infrastructure Setup](#1-aws-infrastructure-setup)
  - [Lambda Functions Deployment](#2-lambda-functions-deployment)
  - [n8n Workflow Configuration](#3-n8n-workflow-configuration)
  - [Airtable Setup](#4-airtable-setup)
- [Usage](#-usage)
- [Configuration](#-configuration)
- [Monitoring & Logging](#-monitoring--logging)
- [Cost Estimation](#-cost-estimation)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🏗 Architecture

```
┌─────────────────┐
│  Google Drive   │
│  (File Upload)  │
└────────┬────────┘
         │
         ↓ (Webhook)
┌─────────────────┐
│   n8n Cloud     │
│  (Orchestrator) │
└────────┬────────┘
         │
         ↓ (Invoke)
┌─────────────────────────────────────────────────────────┐
│                     AWS Lambda                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │  1. video-file-processor                         │  │
│  │     • Downloads from Google Drive                │  │
│  │     • Uploads to S3 temp bucket                  │  │
│  │     • Submits MediaConvert job                   │  │
│  └───────────────────┬──────────────────────────────┘  │
│                      ↓                                  │
│  ┌──────────────────────────────────────────────────┐  │
│  │  AWS MediaConvert                                │  │
│  │     • H.264 encoding (QVBR quality)              │  │
│  │     • 720p minimum resolution                    │  │
│  │     • Audio sync preservation                    │  │
│  └───────────────────┬──────────────────────────────┘  │
│                      ↓ (CloudWatch Event)              │
│  ┌──────────────────────────────────────────────────┐  │
│  │  2. completion-handler                           │  │
│  │     • Processes job results                      │  │
│  │     • Moves to final S3 bucket                   │  │
│  │     • Calculates statistics                      │  │
│  │     • Triggers metadata logger                   │  │
│  └───────────────────┬──────────────────────────────┘  │
│                      ↓                                  │
│  ┌──────────────────────────────────────────────────┐  │
│  │  3. MetaDataLogger                               │  │
│  │     • Logs to Airtable                           │  │
│  │     • Updates processing status                  │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
         │                                    │
         ↓                                    ↓
┌─────────────────┐                  ┌─────────────────┐
│   Amazon S3     │                  │   Amazon SNS    │
│  (Storage)      │                  │ (Notifications) │
└─────────────────┘                  └─────────────────┘
         │
         ↓
┌─────────────────┐
│   Airtable      │
│  (Metadata DB)  │
└─────────────────┘
```

### Data Flow

1. **Upload Detection** - User uploads video to Google Drive
2. **Webhook Trigger** - n8n detects new file and captures metadata
3. **Lambda Invocation** - n8n triggers file processor with file details
4. **Download & Upload** - File downloaded from Drive, uploaded to S3 temp
5. **Compression Decision** - Check if file > 5GB
6. **MediaConvert Job** - If needed, submit high-quality compression job
7. **Event-Driven Completion** - CloudWatch triggers completion handler
8. **Metadata Logging** - Results stored in Airtable
9. **Notification** - Email sent with processing results

---

## 🛠 Technology Stack

### Cloud Infrastructure
- **AWS Lambda** - Serverless compute for processing logic
- **AWS MediaConvert** - Professional-grade video transcoding
- **AWS S3** - Scalable object storage
- **AWS SNS** - Email notifications
- **AWS CloudWatch** - Logging and monitoring
- **AWS EventBridge** - Event-driven triggers

### Workflow Orchestration
- **n8n Cloud** - Low-code workflow automation
- **Google Drive API** - File detection and download

### Data & Storage
- **Airtable** - Metadata database and tracking
- **Amazon S3** - Video file storage

### Programming
- **Python 3.9+** - Lambda function runtime
- **boto3** - AWS SDK for Python

---

## ✅ Prerequisites

Before starting, ensure you have:

- [ ] **AWS Account** with admin access
- [ ] **AWS CLI** installed and configured ([Installation Guide](https://aws.amazon.com/cli/))
- [ ] **n8n Cloud Account** ([Sign up](https://n8n.cloud))
- [ ] **Google Account** with Google Drive access
- [ ] **Airtable Account** ([Sign up](https://airtable.com/signup))
- [ ] **Basic knowledge** of AWS services, Python, and REST APIs

### Required Tools

```bash
# Verify AWS CLI installation
aws --version

# Verify Python installation
python3 --version

# Configure AWS credentials
aws configure
```

---

## 🚀 Installation

### 1. AWS Infrastructure Setup

#### 1.1 Clone the Repository

```bash
git clone https://github.com/yourusername/video-compression-pipeline.git
cd video-compression-pipeline
```

#### 1.2 Create S3 Buckets

```bash
# Create buckets for video storage
aws s3 mb s3://sam-pautrat-temp-processing --region us-east-1
aws s3 mb s3://sam-pautrat-compressed-videos --region us-east-1
```

#### 1.3 Create IAM Roles

**MediaConvert Service Role:**
```bash
# Create the role
aws iam create-role \
    --role-name MediaConvertServiceRole \
    --assume-role-policy-document file://aws/iam-policies/mediaconvert-trust-policy.json

# Attach policy
aws iam put-role-policy \
    --role-name MediaConvertServiceRole \
    --policy-name MediaConvertServicePolicy \
    --policy-document file://aws/iam-policies/mediaconvert-service-policy.json
```

**Lambda Execution Role:**
```bash
# Create the role
aws iam create-role \
    --role-name LambdaExecutionRole \
    --assume-role-policy-document file://aws/iam-policies/lambda-trust-policy.json

# Attach policy
aws iam put-role-policy \
    --role-name LambdaExecutionRole \
    --policy-name LambdaExecutionPolicy \
    --policy-document file://aws/iam-policies/lambda-execution-policy.json
```

#### 1.4 Create SNS Topic

```bash
# Create topic
aws sns create-topic --name video-compression-notifications --region us-east-1

# Subscribe your email (replace with your email)
aws sns subscribe \
    --topic-arn arn:aws:sns:us-east-1:YOUR-ACCOUNT-ID:video-compression-notifications \
    --protocol email \
    --notification-endpoint your-email@example.com \
    --region us-east-1
```

#### 1.5 Get MediaConvert Endpoint

```bash
# Get your MediaConvert endpoint URL
aws mediaconvert describe-endpoints --region us-east-1
```

**Save this endpoint URL - you'll need it later!**

---

### 2. Lambda Functions Deployment

#### 2.1 Package Lambda Functions

Each Lambda function needs to be packaged with its dependencies:

```bash
cd lambda-functions

# Package video-file-processor
cd video-file-processor
pip install -r requirements.txt -t package/
cp lambda_function.py package/
cd package && zip -r ../video-file-processor.zip . && cd ..

# Package completion-handler
cd ../completion-handler
pip install -r requirements.txt -t package/
cp lambda_function.py package/
cd package && zip -r ../completion-handler.zip . && cd ..

# Package MetaDataLogger
cd ../MetaDataLogger
pip install -r requirements.txt -t package/
cp lambda_function.py package/
cd package && zip -r ../MetaDataLogger.zip . && cd ..
```

#### 2.2 Deploy Lambda Functions

**Deploy video-file-processor:**
```bash
aws lambda create-function \
    --function-name video-file-processor \
    --runtime python3.9 \
    --role arn:aws:iam::YOUR-ACCOUNT-ID:role/LambdaExecutionRole \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://video-file-processor.zip \
    --timeout 900 \
    --memory-size 512 \
    --region us-east-1
```

**Deploy completion-handler:**
```bash
aws lambda create-function \
    --function-name completion-handler \
    --runtime python3.9 \
    --role arn:aws:iam::YOUR-ACCOUNT-ID:role/LambdaExecutionRole \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://completion-handler.zip \
    --timeout 300 \
    --memory-size 256 \
    --region us-east-1
```

**Deploy MetaDataLogger:**
```bash
aws lambda create-function \
    --function-name MetaDataLogger \
    --runtime python3.9 \
    --role arn:aws:iam::YOUR-ACCOUNT-ID:role/LambdaExecutionRole \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://MetaDataLogger.zip \
    --timeout 60 \
    --memory-size 128 \
    --region us-east-1
```

#### 2.3 Configure Environment Variables

See [Configuration Guide](docs/CONFIGURATION.md) for detailed environment variable setup.

#### 2.4 Set Up CloudWatch Event Rule

```bash
# Create event rule for MediaConvert completion
aws events put-rule \
    --name MediaConvertJobStateChange \
    --event-pattern '{"source":["aws.mediaconvert"],"detail-type":["MediaConvert Job State Change"],"detail":{"status":["COMPLETE","ERROR"]}}' \
    --state ENABLED \
    --region us-east-1

# Add Lambda as target
aws events put-targets \
    --rule MediaConvertJobStateChange \
    --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:YOUR-ACCOUNT-ID:function:completion-handler" \
    --region us-east-1

# Grant permission
aws lambda add-permission \
    --function-name completion-handler \
    --statement-id mediaconvert-event-invoke \
    --action lambda:InvokeFunction \
    --principal events.amazonaws.com \
    --region us-east-1
```

---

### 3. n8n Workflow Configuration

#### 3.1 Create IAM User for n8n

```bash
# Create user
aws iam create-user --user-name n8n-lambda-invoker

# Create access key
aws iam create-access-key --user-name n8n-lambda-invoker

# Grant Lambda invoke permission
aws iam put-user-policy \
    --user-name n8n-lambda-invoker \
    --policy-name LambdaInvokePolicy \
    --policy-document file://aws/iam-policies/n8n-lambda-invoke-policy.json
```

**Save the Access Key ID and Secret Access Key!**

#### 3.2 Import n8n Workflow

1. Log in to [n8n Cloud](https://app.n8n.cloud)
2. Click **"New Workflow"**
3. Import the workflow JSON: `n8n/workflow.json`
4. Configure credentials:
   - **Google Drive OAuth2** - Connect your Google account
   - **AWS Credentials** - Use the n8n IAM user credentials

#### 3.3 Configure Workflow Nodes

**Google Drive Trigger:**
- Event: File Created
- Folder: Select your target folder
- File Extensions: `mp4` (optional)

**AWS Lambda Node:**
- Function: `video-file-processor`
- Region: `us-east-1`
- Payload: (see workflow JSON)

---

### 4. Airtable Setup

#### 4.1 Create Base

1. Go to [Airtable.com](https://airtable.com)
2. Create new base: **"Video Processing Pipeline"**
3. Rename table to: **"Processed Videos"**

#### 4.2 Create Table Schema

Create these fields in order:

| Field Name | Type | Configuration |
|------------|------|---------------|
| File Name | Single line text | Primary field |
| Original Size (MB) | Number | 2 decimals |
| Compressed Size (MB) | Number | 2 decimals |
| Duration (seconds) | Number | 0 decimals |
| Processing Time (minutes) | Number | 2 decimals |
| Status | Single select | Processing, Completed, Failed, Retrying |
| Original Uploader | Single line text | |
| Upload Date | Date | Include time |
| Processing Date | Date | Include time |
| Completion Date | Date | Include time |
| Original URL | URL | |
| Compressed URL | URL | |
| Job ID | Single line text | |
| Error Message | Long text | |

#### 4.3 Get API Credentials

1. **Base ID**: Go to https://airtable.com/api → Select your base → Copy Base ID
2. **Personal Access Token**: 
   - Go to https://airtable.com/create/tokens
   - Create new token with `data.records:read` and `data.records:write` scopes
   - Grant access to your base
   - Copy the token

#### 4.4 Update Lambda Environment Variables

Add to `MetaDataLogger` function:
```
AIRTABLE_BASE_ID=appXXXXXXXXXXXXXX
AIRTABLE_TABLE_NAME=Processed Videos
AIRTABLE_API_KEY=patXXXXXXXXXXXXXX
```

---

## 📖 Usage

### Basic Workflow

1. **Upload video** to your configured Google Drive folder
2. **Automatic processing** begins immediately
3. **Monitor progress** via email notifications
4. **Check results** in Airtable dashboard
5. **Download compressed video** from S3

### Testing the Pipeline

**Test with a sample file:**

```bash
# Upload a test video to your Google Drive folder
# Or use the provided test script
python tests/upload_test_video.py
```

**Monitor execution:**
- n8n dashboard for workflow status
- AWS CloudWatch logs for Lambda execution
- Airtable for processing records
- Email for notifications

---

## ⚙️ Configuration

### Environment Variables

See detailed configuration in [CONFIGURATION.md](docs/CONFIGURATION.md)

**Quick Reference:**

```bash
# video-file-processor
TEMP_BUCKET=sam-pautrat-temp-processing
COMPRESSED_BUCKET=sam-pautrat-compressed-videos
MEDIACONVERT_ROLE=arn:aws:iam::ACCOUNT-ID:role/MediaConvertServiceRole
SNS_TOPIC=arn:aws:sns:us-east-1:ACCOUNT-ID:video-compression-notifications
MEDIACONVERT_ENDPOINT=https://XXXXX.mediaconvert.us-east-1.amazonaws.com

# completion-handler (same as above +)
METADATA_LOGGER_FUNCTION=MetaDataLogger

# MetaDataLogger
AIRTABLE_BASE_ID=appXXXXXXXXXXXX
AIRTABLE_TABLE_NAME=Processed Videos
AIRTABLE_API_KEY=patXXXXXXXXXXXX
```

### MediaConvert Settings

Current compression settings prioritize quality:
- **Codec**: H.264
- **Rate Control**: QVBR (Quality 8)
- **Resolution**: 1280x720 minimum
- **Quality Tuning**: Multi-pass HQ
- **Max Bitrate**: 5 Mbps

Modify in: `aws/mediaconvert-job-template.json`

---

## 📊 Monitoring & Logging

### CloudWatch Dashboards

View logs for each Lambda function:
```bash
# video-file-processor logs
aws logs tail /aws/lambda/video-file-processor --follow

# completion-handler logs
aws logs tail /aws/lambda/completion-handler --follow

# MetaDataLogger logs
aws logs tail /aws/lambda/MetaDataLogger --follow
```

### Airtable Dashboard

Track all processing jobs in real-time:
- Processing status
- Compression statistics
- Error messages
- Performance metrics

### SNS Notifications

Email notifications sent for:
- ✅ Processing started
- ✅ Processing completed (with stats)
- ❌ Processing failed (with errors)

---

## 💰 Cost Estimation

### AWS Costs (Monthly, 100 files/day)

| Service | Usage | Cost |
|---------|-------|------|
| Lambda | 3000 invocations | $0.60 |
| MediaConvert | 100 hours video | $300-500 |
| S3 Storage | 1TB | $23 |
| SNS | 3000 emails | $0.50 |
| Data Transfer | 500GB | $45 |
| **Total** | | **~$370-570** |

### Third-Party Services

| Service | Plan | Cost |
|---------|------|------|
| n8n Cloud | Starter | $20-50 |
| Airtable | Pro | $20 |
| **Total** | | **$40-70** |

**Grand Total: ~$410-640/month** for 100 files/day

---

## 🐛 Troubleshooting

### Common Issues

**Issue**: Lambda timeout errors
- **Solution**: Increase timeout to 15 minutes (max)
- Check memory allocation (512MB+)

**Issue**: MediaConvert job fails
- **Solution**: Verify IAM role permissions
- Check input file format compatibility

**Issue**: Airtable not updating
- **Solution**: Verify API key and base ID
- Check Personal Access Token scopes

**Issue**: n8n workflow not triggering
- **Solution**: Verify Google Drive webhook
- Check AWS credentials in n8n

See detailed troubleshooting in [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

```bash
# Clone repository
git clone https://github.com/yourusername/video-compression-pipeline.git
cd video-compression-pipeline

# Install development dependencies
pip install -r requirements-dev.txt

# Run tests
python -m pytest tests/

# Run linter
flake8 lambda-functions/
```

---

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- AWS MediaConvert team for high-quality transcoding
- n8n community for workflow automation
- Airtable for flexible data management

---

## 📞 Support

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/yourusername/video-compression-pipeline/issues)
- **Email**: your-email@example.com

---

**Made with ❤️ for dubbing studios and content creators**


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
