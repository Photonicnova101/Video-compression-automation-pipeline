# API Documentation

## Table of Contents

- [Overview](#overview)
- [Lambda Function APIs](#lambda-function-apis)
- [Airtable API Integration](#airtable-api-integration)
- [AWS Service APIs](#aws-service-apis)
- [Event Schemas](#event-schemas)
- [Error Codes](#error-codes)

---

## Overview

This document describes the APIs and interfaces used in the Video Compression Pipeline. The system uses:
- AWS Lambda function invocation APIs
- Airtable REST API
- AWS MediaConvert API
- AWS S3 API
- AWS SNS API

---

## Lambda Function APIs

### 1. video-file-processor

**Function Name**: `video-file-processor`  
**Runtime**: Python 3.9  
**Invocation Type**: RequestResponse (Synchronous)

#### Input Event Schema

```json
{
  "body": "{\"fileUrl\":\"string\",\"fileName\":\"string\",\"fileSize\":number,\"uploader\":\"string\"}"
}
```

Or direct format:

```json
{
  "fileUrl": "string",
  "fileName": "string",
  "fileSize": number,
  "uploader": "string"
}
```

#### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| fileUrl | string | Yes | Google Drive file URL |
| fileName | string | Yes | Original filename with extension |
| fileSize | number | Yes | File size in bytes |
| uploader | string | No | Email of user who uploaded file |

#### Example Request

```json
{
  "body": "{\"fileUrl\":\"https://drive.google.com/file/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/view\",\"fileName\":\"sample-video.mp4\",\"fileSize\":8589934592,\"uploader\":\"user@example.com\"}"
}
```

#### Response Schema

**Success (200)**:
```json
{
  "statusCode": 200,
  "body": "{\"message\":\"File processing started\",\"jobId\":\"1234567890123-abcdef\",\"fileName\":\"sample-video.mp4\",\"originalSize\":8589934592}"
}
```

**Success - No Compression Needed (200)**:
```json
{
  "statusCode": 200,
  "body": "{\"message\":\"File already optimized, moved to final bucket\",\"fileName\":\"small-video.mp4\",\"originalSize\":1073741824}"
}
```

**Error (500)**:
```json
{
  "statusCode": 500,
  "body": "{\"error\":\"Error message details\"}"
}
```

#### Invocation via AWS CLI

```bash
aws lambda invoke \
    --function-name video-file-processor \
    --payload '{"fileUrl":"https://drive.google.com/file/d/TEST/view","fileName":"test.mp4","fileSize":1000000000,"uploader":"test@example.com"}' \
    --cli-binary-format raw-in-base64-out \
    response.json

cat response.json
```

#### Invocation via Python (boto3)

```python
import boto3
import json

lambda_client = boto3.client('lambda', region_name='us-east-1')

payload = {
    "fileUrl": "https://drive.google.com/file/d/TEST/view",
    "fileName": "test.mp4",
    "fileSize": 1000000000,
    "uploader": "test@example.com"
}

response = lambda_client.invoke(
    FunctionName='video-file-processor',
    InvocationType='RequestResponse',
    Payload=json.dumps(payload)
)

result = json.loads(response['Payload'].read())
print(result)
```

---

### 2. completion-handler

**Function Name**: `completion-handler`  
**Runtime**: Python 3.9  
**Invocation Type**: Event (Asynchronous, triggered by EventBridge)

#### Input Event Schema

This function receives CloudWatch Events from MediaConvert:

```json
{
  "version": "0",
  "id": "string",
  "detail-type": "MediaConvert Job State Change",
  "source": "aws.mediaconvert",
  "account": "string",
  "time": "string (ISO 8601)",
  "region": "string",
  "resources": ["string"],
  "detail": {
    "status": "COMPLETE | ERROR",
    "jobId": "string",
    "queue": "string",
    "userMetadata": {
      "OriginalFileName": "string",
      "OriginalSize": "string",
      "Uploader": "string",
      "ProcessingStartTime": "string (ISO 8601)"
    },
    "outputGroupDetails": [...]
  }
}
```

#### Example Event (Success)

```json
{
  "version": "0",
  "id": "12345678-1234-1234-1234-123456789012",
  "detail-type": "MediaConvert Job State Change",
  "source": "aws.mediaconvert",
  "account": "123456789012",
  "time": "2024-01-15T10:30:00Z",
  "region": "us-east-1",
  "resources": [
    "arn:aws:mediaconvert:us-east-1:123456789012:jobs/1234567890123-abcdef"
  ],
  "detail": {
    "status": "COMPLETE",
    "jobId": "1234567890123-abcdef",
    "queue": "arn:aws:mediaconvert:us-east-1:123456789012:queues/Default",
    "userMetadata": {
      "OriginalFileName": "video.mp4",
      "OriginalSize": "8589934592",
      "Uploader": "user@example.com",
      "ProcessingStartTime": "2024-01-15T10:00:00Z"
    },
    "outputGroupDetails": [
      {
        "outputDetails": [
          {
            "outputFilePaths": [
              "s3://sam-pautrat-compressed-videos/compressed/video_compressed.mp4"
            ],
            "durationInMs": 600000,
            "videoDetails": {
              "widthInPx": 1280,
              "heightInPx": 720
            }
          }
        ]
      }
    ]
  }
}
```

#### Response Schema

```json
{
  "statusCode": 200,
  "body": "{\"message\":\"Job completed successfully\",\"jobId\":\"1234567890123-abcdef\",\"result\":{...}}"
}
```

#### Manual Invocation (Testing)

```bash
aws lambda invoke \
    --function-name completion-handler \
    --payload file://test-event-completion.json \
    --cli-binary-format raw-in-base64-out \
    response.json
```

---

### 3. MetaDataLogger

**Function Name**: `MetaDataLogger`  
**Runtime**: Python 3.9  
**Invocation Type**: Event (Asynchronous, triggered by completion-handler)

#### Input Event Schema

**Completion Event**:
```json
{
  "type": "completion",
  "job_info": {
    "job_id": "string",
    "status": "COMPLETE",
    "timestamp": "string (ISO 8601)",
    "user_metadata": {
      "OriginalFileName": "string",
      "OriginalSize": "string",
      "Uploader": "string",
      "ProcessingStartTime": "string (ISO 8601)"
    }
  },
  "result": {
    "job_id": "string",
    "status": "completed",
    "processing_time": number,
    "original_file": {
      "name": "string",
      "size": number,
      "uploader": "string"
    },
    "compressed_files": [
      {
        "bucket": "string
