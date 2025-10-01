"""
MetaData Logger Lambda Function

This function logs video processing metadata to Airtable.
It is triggered by the completion-handler Lambda function after a MediaConvert job finishes.

Environment Variables:
    AIRTABLE_BASE_ID: Airtable base identifier
    AIRTABLE_TABLE_NAME: Name of the Airtable table
    AIRTABLE_API_KEY: Personal Access Token for Airtable API
"""

import json
import os
import logging
import requests
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
AIRTABLE_BASE_ID = os.environ.get('AIRTABLE_BASE_ID', 'your-base-id')
AIRTABLE_TABLE_NAME = os.environ.get('AIRTABLE_TABLE_NAME', 'Processed Videos')
AIRTABLE_API_KEY = os.environ.get('AIRTABLE_API_KEY', 'your-api-key')

# Airtable API configuration
AIRTABLE_API_URL = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{AIRTABLE_TABLE_NAME}"
AIRTABLE_HEADERS = {
    'Authorization': f'Bearer {AIRTABLE_API_KEY}',
    'Content-Type': 'application/json'
}


def lambda_handler(event, context):
    """
    Lambda function handler for logging metadata to Airtable
    
    Args:
        event: Event data from completion-handler Lambda
        context: Lambda context object
        
    Returns:
        dict: Response with status code and Airtable record details
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Determine event type
        event_type = event.get('type', 'completion')
        
        if event_type == 'completion':
            # Handle successful completion
            record_id = log_completion(event['job_info'], event['result'])
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Metadata logged successfully',
                    'recordId': record_id
                })
            }
            
        elif event_type == 'failure':
            # Handle job failure
            record_id = log_failure(event['failure_info'])
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Failure logged successfully',
                    'recordId': record_id
                })
            }
            
    except Exception as e:
        logger.error(f"Error logging metadata: {str(e)}")
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }


def log_completion(job_info, result):
    """
    Log successful completion to Airtable
    
    Args:
        job_info: Job information from MediaConvert
        result: Processing results and statistics
        
    Returns:
        str: Airtable record ID
    """
    try:
        # Calculate file sizes in MB
        original_size_mb = result['original_file']['size'] / (1024 * 1024)
        
        compressed_size_mb = 0
        compressed_url = ''
        if result['compressed_files']:
            compressed_size_mb = result['compressed_files'][0]['size'] / (1024 * 1024)
            compressed_url = result['compressed_files'][0]['url']
        
        # Prepare Airtable record
        record = {
            'fields': {
                'File Name': result['original_file']['name'],
                'Original Size (MB)': round(original_size_mb, 2),
                'Compressed Size (MB)': round(compressed_size_mb, 2),
                'Processing Time (minutes)': result['processing_time'],
                'Status': 'Completed',
                'Original Uploader': result['original_file']['uploader'],
                'Upload Date': datetime.utcnow().isoformat(),
                'Processing Date': job_info['user_metadata'].get('ProcessingStartTime', datetime.utcnow().isoformat()),
                'Completion Date': datetime.utcnow().isoformat(),
                'Compressed URL': compressed_url,
                'Job ID': result['job_id']
            }
        }
        
        # Add compression statistics if available
        if result['compression_stats']:
            compression_ratio = result['compression_stats'].get('compression_ratio', 0)
            if compression_ratio > 0:
                record['fields']['Compression Ratio'] = round(compression_ratio, 2)
        
        # Create record in Airtable
        response = requests.post(
            AIRTABLE_API_URL,
            headers=AIRTABLE_HEADERS,
            json=record
        )
        
        response.raise_for_status()
        result_data = response.json()
        
        record_id = result_data['id']
        logger.info(f"Created Airtable record: {record_id}")
        
        return record_id
        
    except Exception as e:
        logger.error(f"Error logging completion to Airtable: {str(e)}")
        raise


def log_failure(failure_info):
    """
    Log job failure to Airtable
    
    Args:
        failure_info: Failure information from completion-handler
        
    Returns:
        str: Airtable record ID
    """
    try:
        # Calculate file size in MB
        original_size_mb = failure_info['original_file']['size'] / (1024 * 1024)
        
        # Prepare Airtable record
        record = {
            'fields': {
                'File Name': failure_info['original_file']['name'],
                'Original Size (MB)': round(original_size_mb, 2),
                'Status': 'Failed',
                'Original Uploader': failure_info['original_file']['uploader'],
                'Upload Date': datetime.utcnow().isoformat(),
                'Processing Date': failure_info['timestamp'],
                'Error Message': f"{failure_info['error_code']}: {failure_info['error_message']}",
                'Job ID': failure_info['job_id']
            }
        }
        
        # Create record in Airtable
        response = requests.post(
            AIRTABLE_API_URL,
            headers=AIRTABLE_HEADERS,
            json=record
        )
        
        response.raise_for_status()
        result_data = response.json()
        
        record_id = result_data['id']
        logger.info(f"Created Airtable failure record: {record_id}")
        
        return record_id
        
    except Exception as e:
        logger.error(f"Error logging failure to Airtable: {str(e)}")
        raise


def update_record(record_id, fields):
    """
    Update an existing Airtable record
    
    Args:
        record_id: Airtable record ID
        fields: Dictionary of fields to update
        
    Returns:
        dict: Updated record data
    """
    try:
        url = f"{AIRTABLE_API_URL}/{record_id}"
        
        payload = {
            'fields': fields
        }
        
        response = requests.patch(
            url,
            headers=AIRTABLE_HEADERS,
            json=payload
        )
        
        response.raise_for_status()
        result_data = response.json()
        
        logger.info(f"Updated Airtable record: {record_id}")
        
        return result_data
        
    except Exception as e:
        logger.error(f"Error updating Airtable record: {str(e)}")
        raise


def find_record_by_job_id(job_id):
    """
    Find an Airtable record by MediaConvert job ID
    
    Args:
        job_id: MediaConvert job ID
        
    Returns:
        str: Airtable record ID or None if not found
    """
    try:
        # Airtable filter formula
        filter_formula = f"{{Job ID}}='{job_id}'"
        
        params = {
            'filterByFormula': filter_formula
        }
        
        response = requests.get(
            AIRTABLE_API_URL,
            headers=AIRTABLE_HEADERS,
            params=params
        )
        
        response.raise_for_status()
        result_data = response.json()
        
        records = result_data.get('records', [])
        
        if records:
            return records[0]['id']
        
        return None
        
    except Exception as e:
        logger.error(f"Error finding Airtable record: {str(e)}")
        return None


def delete_record(record_id):
    """
    Delete an Airtable record
    
    Args:
        record_id: Airtable record ID
        
    Returns:
        bool: True if successful
    """
    try:
        url = f"{AIRTABLE_API_URL}/{record_id}"
        
        response = requests.delete(
            url,
            headers=AIRTABLE_HEADERS
        )
        
        response.raise_for_status()
        
        logger.info(f"Deleted Airtable record: {record_id}")
        
        return True
        
    except Exception as e:
        logger.error(f"Error deleting Airtable record: {str(e)}")
        return False
