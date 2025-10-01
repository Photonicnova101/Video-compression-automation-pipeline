"""
Video File Processor Lambda Function

This function is triggered by n8n when a new video file is uploaded to Google Drive.
It downloads the file, uploads to S3, and submits a MediaConvert job for compression.

Environment Variables:
    TEMP_BUCKET: S3 bucket for temporary file storage
    COMPRESSED_BUCKET: S3 bucket for final compressed videos
    MEDIACONVERT_ROLE: IAM role ARN for MediaConvert
    SNS_TOPIC: SNS topic ARN for notifications
    MEDIACONVERT_ENDPOINT: MediaConvert endpoint URL
"""

import json
import boto3
import urllib.request
import urllib.parse
import os
import logging
from datetime import datetime
import uuid

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
mediaconvert_client = boto3.client('mediaconvert')
sns_client = boto3.client('sns')

# Environment variables
TEMP_BUCKET = os.environ.get('TEMP_BUCKET', 'sam-pautrat-temp-processing')
COMPRESSED_BUCKET = os.environ.get('COMPRESSED_BUCKET', 'sam-pautrat-compressed-videos')
MEDIACONVERT_ROLE = os.environ.get('MEDIACONVERT_ROLE', 'arn:aws:iam::YOUR-ACCOUNT-ID:role/MediaConvertServiceRole')
SNS_TOPIC = os.environ.get('SNS_TOPIC', 'arn:aws:sns:us-east-1:YOUR-ACCOUNT-ID:video-compression-notifications')
MEDIACONVERT_ENDPOINT = os.environ.get('MEDIACONVERT_ENDPOINT', 'https://YOUR-ENDPOINT.mediaconvert.us-east-1.amazonaws.com')


def lambda_handler(event, context):
    """
    Lambda function handler to process video files from Google Drive
    
    Args:
        event: Event data from n8n webhook
        context: Lambda context object
        
    Returns:
        dict: Response with status code and processing details
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Parse the incoming event from n8n
        file_info = parse_event(event)
        
        # Download file from Google Drive to temp S3 bucket
        s3_key = download_file_to_s3(file_info)
        
        # Check if file needs compression
        if should_compress_file(s3_key):
            # Submit MediaConvert job
            job_id = submit_mediaconvert_job(s3_key, file_info)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'File processing started',
                    'jobId': job_id,
                    'fileName': file_info['name'],
                    'originalSize': file_info['size']
                })
            }
        else:
            # File doesn't need compression, move directly to final bucket
            move_file_to_final_bucket(s3_key, file_info)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'File already optimized, moved to final bucket',
                    'fileName': file_info['name'],
                    'originalSize': file_info['size']
                })
            }
            
    except Exception as e:
        logger.error(f"Error processing file: {str(e)}")
        send_error_notification(str(e), event)
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }


def parse_event(event):
    """
    Parse the incoming event from n8n webhook
    
    Args:
        event: Raw event data
        
    Returns:
        dict: Parsed file information
    """
    try:
        # Handle different event formats
        if 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event
            
        return {
            'url': body['fileUrl'],
            'name': body['fileName'],
            'size': body['fileSize'],
            'uploader': body.get('uploader', 'unknown')
        }
    except Exception as e:
        logger.error(f"Error parsing event: {str(e)}")
        raise ValueError(f"Invalid event format: {str(e)}")


def download_file_to_s3(file_info):
    """
    Download file from Google Drive URL to S3 temp bucket
    
    Args:
        file_info: Dictionary containing file metadata
        
    Returns:
        str: S3 key of uploaded file
    """
    try:
        # Generate unique S3 key
        file_extension = os.path.splitext(file_info['name'])[1]
        s3_key = f"temp/{uuid.uuid4()}{file_extension}"
        
        # Convert Google Drive URL to direct download URL
        direct_url = convert_google_drive_url(file_info['url'])
        
        logger.info(f"Downloading file from: {direct_url}")
        
        # Download file in chunks to handle large files
        with urllib.request.urlopen(direct_url) as response:
            # Initialize multipart upload for large files
            upload_id = s3_client.create_multipart_upload(
                Bucket=TEMP_BUCKET,
                Key=s3_key
            )['UploadId']
            
            parts = []
            part_number = 1
            chunk_size = 100 * 1024 * 1024  # 100MB chunks
            
            while True:
                chunk = response.read(chunk_size)
                if not chunk:
                    break
                    
                # Upload part
                part_response = s3_client.upload_part(
                    Bucket=TEMP_BUCKET,
                    Key=s3_key,
                    PartNumber=part_number,
                    UploadId=upload_id,
                    Body=chunk
                )
                
                parts.append({
                    'ETag': part_response['ETag'],
                    'PartNumber': part_number
                })
                
                part_number += 1
                logger.info(f"Uploaded part {part_number-1}")
            
            # Complete multipart upload
            s3_client.complete_multipart_upload(
                Bucket=TEMP_BUCKET,
                Key=s3_key,
                UploadId=upload_id,
                MultipartUpload={'Parts': parts}
            )
            
        logger.info(f"File uploaded to S3: s3://{TEMP_BUCKET}/{s3_key}")
        return s3_key
        
    except Exception as e:
        logger.error(f"Error downloading file to S3: {str(e)}")
        raise


def convert_google_drive_url(url):
    """
    Convert Google Drive sharing URL to direct download URL
    
    Args:
        url: Google Drive sharing URL
        
    Returns:
        str: Direct download URL
    """
    try:
        # Extract file ID from various Google Drive URL formats
        if '/file/d/' in url:
            file_id = url.split('/file/d/')[1].split('/')[0]
        elif 'id=' in url:
            file_id = url.split('id=')[1].split('&')[0]
        else:
            raise ValueError("Invalid Google Drive URL format")
            
        # Return direct download URL
        return f"https://drive.google.com/uc?export=download&id={file_id}"
        
    except Exception as e:
        logger.error(f"Error converting Google Drive URL: {str(e)}")
        raise


def should_compress_file(s3_key):
    """
    Check if file needs compression based on size
    
    Args:
        s3_key: S3 object key
        
    Returns:
        bool: True if file should be compressed
    """
    try:
        # Get file size from S3
        response = s3_client.head_object(Bucket=TEMP_BUCKET, Key=s3_key)
        file_size_gb = response['ContentLength'] / (1024 * 1024 * 1024)
        
        logger.info(f"File size: {file_size_gb:.2f} GB")
        
        # Compress if file is over 5GB
        return file_size_gb > 5.0
        
    except Exception as e:
        logger.error(f"Error checking file size: {str(e)}")
        # Default to compress if we can't determine size
        return True


def submit_mediaconvert_job(s3_key, file_info):
    """
    Submit MediaConvert job for video compression
    
    Args:
        s3_key: S3 key of input file
        file_info: Dictionary containing file metadata
        
    Returns:
        str: MediaConvert job ID
    """
    try:
        # Set MediaConvert endpoint
        mediaconvert_client._endpoint = boto3.client('mediaconvert', endpoint_url=MEDIACONVERT_ENDPOINT)._endpoint
        
        # Generate output filename
        file_name_without_ext = os.path.splitext(file_info['name'])[0]
        output_key = f"compressed/{file_name_without_ext}_compressed"
        
        # Create MediaConvert job
        job_settings = {
            "Role": MEDIACONVERT_ROLE,
            "Settings": {
                "OutputGroups": [{
                    "Name": "File Group",
                    "OutputGroupSettings": {
                        "Type": "FILE_GROUP_SETTINGS",
                        "FileGroupSettings": {
                            "Destination": f"s3://{COMPRESSED_BUCKET}/{output_key}"
                        }
                    },
                    "Outputs": [{
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
                                    "QualityTuningLevel": "MULTI_PASS_HQ"
                                }
                            }
                        },
                        "AudioDescriptions": [{
                            "CodecSettings": {
                                "Codec": "AAC",
                                "AacSettings": {
                                    "Bitrate": 128000,
                                    "SampleRate": 48000
                                }
                            }
                        }],
                        "ContainerSettings": {
                            "Container": "MP4"
                        },
                        "NameModifier": "_compressed"
                    }]
                }],
                "Inputs": [{
                    "FileInput": f"s3://{TEMP_BUCKET}/{s3_key}",
                    "AudioSelectors": {
                        "Audio Selector 1": {
                            "DefaultSelection": "DEFAULT"
                        }
                    },
                    "VideoSelector": {
                        "ColorSpace": "FOLLOW"
                    }
                }]
            },
            "UserMetadata": {
                "OriginalFileName": file_info['name'],
                "OriginalSize": str(file_info['size']),
                "Uploader": file_info['uploader'],
                "ProcessingStartTime": datetime.utcnow().isoformat()
            }
        }
        
        # Submit job
        response = mediaconvert_client.create_job(**job_settings)
        job_id = response['Job']['Id']
        
        logger.info(f"MediaConvert job submitted: {job_id}")
        
        # Send notification
        send_processing_notification(job_id, file_info)
        
        return job_id
        
    except Exception as e:
        logger.error(f"Error submitting MediaConvert job: {str(e)}")
        raise


def move_file_to_final_bucket(s3_key, file_info):
    """
    Move file directly to final bucket if no compression needed
    
    Args:
        s3_key: S3 key of file in temp bucket
        file_info: Dictionary containing file metadata
    """
    try:
        # Copy to final bucket
        copy_source = {'Bucket': TEMP_BUCKET, 'Key': s3_key}
        final_key = f"uncompressed/{file_info['name']}"
        
        s3_client.copy_object(
            CopySource=copy_source,
            Bucket=COMPRESSED_BUCKET,
            Key=final_key
        )
        
        # Delete from temp bucket
        s3_client.delete_object(Bucket=TEMP_BUCKET, Key=s3_key)
        
        logger.info(f"File moved to final bucket: {final_key}")
        
    except Exception as e:
        logger.error(f"Error moving file to final bucket: {str(e)}")
        raise


def send_processing_notification(job_id, file_info):
    """
    Send SNS notification that processing has started
    
    Args:
        job_id: MediaConvert job ID
        file_info: Dictionary containing file metadata
    """
    try:
        message = {
            "status": "processing_started",
            "jobId": job_id,
            "fileName": file_info['name'],
            "originalSize": file_info['size'],
            "uploader": file_info['uploader'],
            "timestamp": datetime.utcnow().isoformat()
        }
        
        sns_client.publish(
            TopicArn=SNS_TOPIC,
            Message=json.dumps(message, indent=2),
            Subject=f"Video Processing Started: {file_info['name']}"
        )
        
        logger.info(f"Processing notification sent for job: {job_id}")
        
    except Exception as e:
        logger.error(f"Error sending processing notification: {str(e)}")


def send_error_notification(error_message, event):
    """
    Send SNS notification for processing errors
    
    Args:
        error_message: Error description
        event: Original event data
    """
    try:
        message = {
            "status": "error",
            "error": error_message,
            "event": str(event),
            "timestamp": datetime.utcnow().isoformat()
        }
        
        sns_client.publish(
            TopicArn=SNS_TOPIC,
            Message=json.dumps(message, indent=2),
            Subject="Video Processing Error"
        )
        
        logger.info("Error notification sent")
        
    except Exception as e:
        logger.error(f"Error sending error notification: {str(e)}")
