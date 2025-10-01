"""
Completion Handler Lambda Function

This function is triggered by CloudWatch Events when MediaConvert jobs complete.
It processes the job results, moves compressed files to final storage, and triggers
metadata logging.

Environment Variables:
    TEMP_BUCKET: S3 bucket for temporary file storage
    COMPRESSED_BUCKET: S3 bucket for final compressed videos
    SNS_TOPIC: SNS topic ARN for notifications
    METADATA_LOGGER_FUNCTION: Name of the metadata logger Lambda function
    MEDIACONVERT_ENDPOINT: MediaConvert endpoint URL
"""

import json
import boto3
import os
import logging
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
mediaconvert_client = boto3.client('mediaconvert')
sns_client = boto3.client('sns')
lambda_client = boto3.client('lambda')

# Environment variables
TEMP_BUCKET = os.environ.get('TEMP_BUCKET', 'sam-pautrat-temp-processing')
COMPRESSED_BUCKET = os.environ.get('COMPRESSED_BUCKET', 'sam-pautrat-compressed-videos')
SNS_TOPIC = os.environ.get('SNS_TOPIC', 'arn:aws:sns:us-east-1:YOUR-ACCOUNT-ID:video-compression-notifications')
METADATA_LOGGER_FUNCTION = os.environ.get('METADATA_LOGGER_FUNCTION', 'MetaDataLogger')
MEDIACONVERT_ENDPOINT = os.environ.get('MEDIACONVERT_ENDPOINT', 'https://YOUR-ENDPOINT.mediaconvert.us-east-1.amazonaws.com')


def lambda_handler(event, context):
    """
    Lambda function handler for MediaConvert job completion events
    
    Args:
        event: CloudWatch event data
        context: Lambda context object
        
    Returns:
        dict: Response with status code and processing details
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Parse MediaConvert event
        job_info = parse_mediaconvert_event(event)
        
        if job_info['status'] == 'COMPLETE':
            # Handle successful completion
            result = handle_successful_completion(job_info)
            
            # Send completion notification
            send_completion_notification(job_info, result)
            
            # Log metadata to Airtable
            log_metadata_to_airtable(job_info, result)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Job completed successfully',
                    'jobId': job_info['job_id'],
                    'result': result
                })
            }
            
        elif job_info['status'] == 'ERROR':
            # Handle failed completion
            handle_failed_completion(job_info)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Job failed, error handled',
                    'jobId': job_info['job_id']
                })
            }
            
    except Exception as e:
        logger.error(f"Error handling completion event: {str(e)}")
        send_handler_error_notification(str(e), event)
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }


def parse_mediaconvert_event(event):
    """
    Parse MediaConvert CloudWatch event
    
    Args:
        event: Raw CloudWatch event
        
    Returns:
        dict: Parsed job information
    """
    try:
        detail = event['detail']
        
        return {
            'job_id': detail['jobId'],
            'status': detail['status'],
            'timestamp': event['time'],
            'user_metadata': detail.get('userMetadata', {}),
            'output_group_details': detail.get('outputGroupDetails', [])
        }
        
    except Exception as e:
        logger.error(f"Error parsing MediaConvert event: {str(e)}")
        raise ValueError(f"Invalid MediaConvert event format: {str(e)}")


def handle_successful_completion(job_info):
    """
    Handle successful MediaConvert job completion
    
    Args:
        job_info: Parsed job information
        
    Returns:
        dict: Processing results and statistics
    """
    try:
        # Set MediaConvert endpoint
        mediaconvert_client._endpoint = boto3.client('mediaconvert', endpoint_url=MEDIACONVERT_ENDPOINT)._endpoint
        
        # Get detailed job information
        job_response = mediaconvert_client.get_job(Id=job_info['job_id'])
        job_details = job_response['Job']
        
        # Extract output file information
        output_files = []
        for output_group in job_details['Settings']['OutputGroups']:
            destination = output_group['OutputGroupSettings']['FileGroupSettings']['Destination']
            
            for output in output_group['Outputs']:
                name_modifier = output.get('NameModifier', '')
                output_files.append({
                    'destination': destination,
                    'name_modifier': name_modifier
                })
        
        # Get file sizes and metadata
        result = {
            'job_id': job_info['job_id'],
            'status': 'completed',
            'processing_time': calculate_processing_time(job_details),
            'original_file': {
                'name': job_info['user_metadata'].get('OriginalFileName', 'unknown'),
                'size': int(job_info['user_metadata'].get('OriginalSize', 0)),
                'uploader': job_info['user_metadata'].get('Uploader', 'unknown')
            },
            'compressed_files': [],
            'compression_stats': {}
        }
        
        # Get compressed file details
        for output_file in output_files:
            compressed_file_info = get_compressed_file_info(output_file)
            result['compressed_files'].append(compressed_file_info)
        
        # Calculate compression statistics
        result['compression_stats'] = calculate_compression_stats(result)
        
        # Clean up temporary files
        cleanup_temp_files(job_details)
        
        logger.info(f"Job {job_info['job_id']} completed successfully")
        
        return result
        
    except Exception as e:
        logger.error(f"Error handling successful completion: {str(e)}")
        raise


def handle_failed_completion(job_info):
    """
    Handle failed MediaConvert job completion
    
    Args:
        job_info: Parsed job information
    """
    try:
        # Set MediaConvert endpoint
        mediaconvert_client._endpoint = boto3.client('mediaconvert', endpoint_url=MEDIACONVERT_ENDPOINT)._endpoint
        
        # Get detailed job information
        job_response = mediaconvert_client.get_job(Id=job_info['job_id'])
        job_details = job_response['Job']
        
        # Extract error information
        error_message = job_details.get('ErrorMessage', 'Unknown error')
        error_code = job_details.get('ErrorCode', 'UNKNOWN')
        
        # Create failure record
        failure_info = {
            'job_id': job_info['job_id'],
            'status': 'failed',
            'error_message': error_message,
            'error_code': error_code,
            'original_file': {
                'name': job_info['user_metadata'].get('OriginalFileName', 'unknown'),
                'size': int(job_info['user_metadata'].get('OriginalSize', 0)),
                'uploader': job_info['user_metadata'].get('Uploader', 'unknown')
            },
            'timestamp': job_info['timestamp
