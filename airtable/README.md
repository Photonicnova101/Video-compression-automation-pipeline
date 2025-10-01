# Airtable Configuration

This directory contains the Airtable base schema and setup instructions for the Video Compression Pipeline.

## Overview

Airtable serves as the metadata database and tracking system for all processed videos. It provides:
- Real-time tracking of processing status
- Historical record of all processed videos
- Compression statistics and analytics
- Error logging and debugging information

---

## Quick Setup

### Step 1: Create Airtable Account

1. Go to [airtable.com](https://airtable.com)
2. Sign up for a free account (or use existing account)
3. Verify your email address

### Step 2: Create Base

1. Click **"Create a base"**
2. Choose **"Start from scratch"**
3. Name your base: **"Video Processing Pipeline"**
4. Click **"Create base"**

### Step 3: Set Up Table Schema

#### Option A: Manual Setup

1. Rename the default table from "Table 1" to **"Processed Videos"**
2. Delete default fields (Name, Notes, etc.)
3. Add fields according to the [Field Definitions](#field-definitions) section below

#### Option B: Import from Schema (Recommended)

**Note:** Airtable doesn't support direct JSON import, but you can use the schema.json as a reference guide.

1. Open `schema.json` in this directory
2. Follow the field definitions to create each field
3. Use the exact names and types specified

### Step 4: Get API Credentials

#### Get Base ID:
1. Go to [airtable.com/api](https://airtable.com/api)
2. Click on your **"Video Processing Pipeline"** base
3. In the URL or documentation, find the Base ID
4. Format: `appXXXXXXXXXXXXXX`
5. Copy and save this ID

#### Get Personal Access Token:
1. Go to [airtable.com/create/tokens](https://airtable.com/create/tokens)
2. Click **"Create new token"**
3. Name: **"Video Compression Pipeline"**
4. Add scopes:
   - ✅ `data.records:read`
   - ✅ `data.records:write`
5. Add access to bases:
   - ✅ **"Video Processing Pipeline"**
6. Click **"Create token"**
7. Copy the token (starts with `pat_...`)
8. **Important:** Save this token securely - it won't be shown again!

### Step 5: Configure Lambda Function

Update the MetaDataLogger Lambda function with your credentials:

```bash
aws lambda update-function-configuration \
    --function-name MetaDataLogger \
    --environment Variables='{
        "AIRTABLE_BASE_ID":"appYOUR_BASE_ID",
        "AIRTABLE_TABLE_NAME":"Processed Videos",
        "AIRTABLE_API_KEY":"patYOUR_API_TOKEN"
    }' \
    --region us-east-1
```

---

## Field Definitions

### Primary Field

**File Name**
- **Type:** Single line text
- **Description:** Original filename from upload
- **Example:** `marketing-video-2024.mp4`
- **Primary Field:** Yes

### Size Fields

**Original Size (MB)**
- **Type:** Number
- **Format:** Decimal (2 places)
- **Description:** File size before compression
- **Example:** `8543.27`

**Compressed Size (MB)**
- **Type:** Number
- **Format:** Decimal (2 places)
- **Description:** File size after compression
- **Example:** `3421.15`

### Time Fields

**Duration (seconds)**
- **Type:** Number
- **Format:** Integer (0 decimals)
- **Description:** Video length in seconds
- **Example:** `1847` (30 minutes, 47 seconds)

**Processing Time (minutes)**
- **Type:** Number
- **Format:** Decimal (2 places)
- **Description:** Time taken to compress
- **Example:** `22.45`

### Status Field

**Status**
- **Type:** Single select
- **Options:**
  - 🟡 **Processing** (Yellow) - Currently being compressed
  - 🟢 **Completed** (Green) - Successfully compressed
  - 🔴 **Failed** (Red) - Processing failed
  - 🟠 **Retrying** (Orange) - Attempting to retry after failure
- **Default:** Processing

### User Field

**Original Uploader**
- **Type:** Single line text
- **Description:** Email of user who uploaded file
- **Example:** `user@company.com`

### Date/Time Fields

**Upload Date**
- **Type:** Date with time
- **Format:** Local date and 24-hour time
- **Description:** When file was uploaded to Google Drive
- **Example:** `2024-01-15 10:30`

**Processing Date**
- **Type:** Date with time
- **Format:** Local date and 24-hour time
- **Description:** When compression started
- **Example:** `2024-01-15 10:35`

**Completion Date**
- **Type:** Date with time
- **Format:** Local date and 24-hour time
- **Description:** When compression finished
- **Example:** `2024-01-15 11:00`

### URL Fields

**Original URL**
- **Type:** URL
- **Description:** Link to original file in Google Drive
- **Example:** `https://drive.google.com/file/d/...`

**Compressed URL**
- **Type:** URL
- **Description:** S3 URL of compressed video
- **Example:** `https://sam-pautrat-compressed-videos.s3.amazonaws.com/...`

### Technical Fields

**Resolution**
- **Type:** Single select
- **Options:**
  - 🔵 **720p** (Blue)
  - 🔷 **1080p** (Cyan)
  - 🟣 **4K** (Purple)
  - ⚪ **Other** (Gray)

**Compression Ratio**
- **Type:** Formula
- **Formula:** `ROUND({Original Size (MB)} / {Compressed Size (MB)}, 2)`
- **Description:** Automatic calculation of compression ratio
- **Example:** `2.50` (original was 2.5x larger)

**Job ID**
- **Type:** Single line text
- **Description:** AWS MediaConvert job identifier
- **Example:** `1234567890123-abcdef`

**Error Message**
- **Type:** Long text
- **Description:** Error details if processing failed
- **Example:** `Input file format not supported: codec xyz`

---

## Views Configuration

### 1. All Videos (Default)
**Purpose:** See all processed videos

**Configuration:**
- Type: Grid
- No filters
- Sort: Most recent first

### 2. Active Processing
**Purpose:** Monitor videos currently being processed

**Configuration:**
- Type: Grid
- Filter: Status is "Processing" OR "Retrying"
- Sort: Processing Date (newest first)
- Auto-refresh: Recommended

### 3. Recent Completions
**Purpose:** View recently completed videos

**Configuration:**
- Type: Grid
- Filter: Status is "Completed"
- Sort: Completion Date (newest first)
- Limit: 50 records

### 4. Failures
**Purpose:** Track and debug failed processing attempts

**Configuration:**
- Type: Grid
- Filter: Status is "Failed"
- Sort: Processing Date (newest first)
- Color: By Status field (shows red)

### 5. Compression Stats
**Purpose:** Analyze compression efficiency

**Configuration:**
- Type: Grid
- Visible fields: File Name, Original Size, Compressed Size, Compression Ratio, Processing Time, Status
- Sort: Compression Ratio (highest first)

### 6. By Uploader
**Purpose:** See who is uploading videos

**Configuration:**
- Type: Grid
- Group by: Original Uploader
- Sort: Upload Date (newest first)

### 7. Timeline
**Purpose:** Calendar view of processing activity

**Configuration:**
- Type: Calendar
- Date field: Processing Date
- Good for seeing processing patterns over time

---

## Sample Data

Here's an example of what a completed record looks like:

```json
{
  "File Name": "marketing-campaign-video.mp4",
  "Original Size (MB)": 8543.27,
  "Compressed Size (MB)": 3421.15,
  "Duration (seconds)": 1847,
  "Processing Time (minutes)": 22.45,
  "Status": "Completed",
  "Original Uploader": "marketing@company.com",
  "Upload Date": "2024-01-15T10:30:00.000Z",
  "Processing Date": "2024-01-15T10:35:00.000Z",
  "Completion Date": "2024-01-15T11:00:00.000Z",
  "Original URL": "https://drive.google.com/file/d/abc123/view",
  "Compressed URL": "https://sam-pautrat-compressed-videos.s3.amazonaws.com/compressed/marketing-campaign-video_compressed.mp4",
  "Resolution": "720p",
  "Compression Ratio": 2.50,
  "Job ID": "1705318500123-abcdef",
  "Error Message": null
}
```

---

## API Usage

### Create Record (Python Example)

```python
import requests
import json

AIRTABLE_BASE_ID = "appXXXXXXXXXXXXXX"
AIRTABLE_TABLE_NAME = "Processed Videos"
AIRTABLE_API_KEY = "patXXXXXXXXXXXXXX"

url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{AIRTABLE_TABLE_NAME}"

headers = {
    "Authorization": f"Bearer {AIRTABLE_API_KEY}",
    "Content-Type": "application/json"
}

data = {
    "fields": {
        "File Name": "test-video.mp4",
        "Original Size (MB)": 1000.50,
        "Status": "Processing",
        "Original Uploader": "test@example.com",
        "Upload Date": "2024-01-15T10:00:00.000Z"
    }
}

response = requests.post(url, headers=headers, json=data)
print(response.json())
```

### Update Record (Python Example)

```python
record_id = "recXXXXXXXXXXXXXX"

url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{AIRTABLE_TABLE_NAME}/{record_id}"

data = {
    "fields": {
        "Status": "Completed",
        "Compressed Size (MB)": 400.25,
        "Completion Date": "2024-01-15T10:30:00.000Z"
    }
}

response = requests.patch(url, headers=headers, json=data)
print(response.json())
```

### Query Records (Python Example)

```python
# Get all failed videos
url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{AIRTABLE_TABLE_NAME}"

params = {
    "filterByFormula": "{Status}='Failed'",
    "sort[0][field]": "Processing Date",
    "sort[0][direction]": "desc"
}

response = requests.get(url, headers=headers, params=params)
print(response.json())
```

---

## Best Practices

### 1. Data Entry
- Let the Lambda function handle record creation automatically
- Only manually edit records for corrections
- Use consistent date/time formats

### 2. Status Management
- "Processing" → Set when job starts
- "Completed" → Set when job succeeds
- "Failed" → Set when job fails
- "Retrying" → Set on retry attempts

### 3. View Organization
- Use "Active Processing" view during business hours
- Check "Failures" view daily
- Review "Compression Stats" weekly for optimization

### 4. Data Cleanup
- Archive old records (>90 days) periodically
- Keep failed records for debugging
- Export data regularly for backups

### 5. Performance
- Limit view record counts for faster loading
- Use filters to reduce visible data
- Avoid complex formulas on large datasets

---

## Troubleshooting

### Issue: Records Not Being Created

**Problem:** Lambda function runs but no Airtable records appear

**Solutions:**

1. **Check API credentials:**
   ```bash
   aws lambda get-function-configuration \
       --function-name MetaDataLogger \
       --query 'Environment.Variables'
   ```

2. **Verify Personal Access Token:**
   - Ensure token has `data.records:write` scope
   - Check token hasn't been revoked
   - Verify base access is granted

3. **Check Lambda logs:**
   ```bash
   aws logs tail /aws/lambda/MetaDataLogger --follow
   ```

4. **Test API connection:**
   ```bash
   curl -X GET "https://api.airtable.com/v0/YOUR_BASE_ID/Processed%20Videos" \
       -H "Authorization: Bearer YOUR_PAT"
   ```

### Issue: Field Validation Errors

**Problem:** Error "Unknown field name" or "Invalid field type"

**Solutions:**

1. **Verify field names match exactly:**
   - Field names are case-sensitive
   - Check for extra spaces
   - "Original Size (MB)" not "Original Size(MB)"

2. **Check field types:**
   - Number fields need numeric values
   - Date fields need ISO 8601 format
   - Single select must use exact option names

3. **Common mismatches:**
   ```python
   # Wrong
   "Original Size": "1000 MB"  # String to Number field
   
   # Correct
   "Original Size (MB)": 1000.0  # Number to Number field
   ```

### Issue: API Rate Limits

**Problem:** Error "429 Too Many Requests"

**Solutions:**

1. **Airtable limits:**
   - 5 requests per second per base
   - Implement retry logic with backoff

2. **Add retry in Lambda:**
   ```python
   import time
   from requests.adapters import HTTPAdapter
   from requests.packages.urllib3.util.retry import Retry
   
   session = requests.Session()
   retry = Retry(total=3, backoff_factor=1)
   adapter = HTTPAdapter(max_retries=retry)
   session.mount('https://', adapter)
   ```

### Issue: Missing Data in Records

**Problem:** Some fields are empty when they shouldn't be

**Solutions:**

1. **Check Lambda payload:**
   - Verify all data is passed from completion-handler
   - Check for null/undefined values

2. **Add default values:**
   ```python
   compressed_size = result.get('compressed_size', 0)
   ```

3. **Validate before sending:**
   ```python
   if not file_name or not status:
       logger.error("Missing required fields")
       return
   ```

---

## Analytics & Reporting

### Key Metrics to Track

1. **Average Compression Ratio:**
   - Shows compression efficiency
   - Target: 2.0-3.0x

2. **Average Processing Time:**
   - Helps predict job duration
   - Track by file size ranges

3. **Success Rate:**
   - Completed / Total jobs
   - Target: >95%

4. **Storage Savings:**
   - Sum(Original Size - Compressed Size)
   - Shows cost benefit

### Creating Dashboard

Use Airtable's interface designer:

1. Add **"Interface"** to your base
2. Create dashboard with:
   - Record count by status
   - Total storage saved
   - Average compression ratio
   - Recent failures list

### Exporting Data

```bash
# Export all records to CSV
# In Airtable: Grid view → ⋮ → Download CSV

# Or via API:
curl "https://api.airtable.com/v0/YOUR_BASE_ID/Processed%20Videos" \
    -H "Authorization: Bearer YOUR_PAT" \
    > backup.json
```

---

## Integration with Other Tools

### Zapier Integration
Connect Airtable to Slack, email, or other services:
1. Create Zap triggered by new Airtable record
2. Filter by Status = "Failed"
3. Send notification to Slack channel

### Google Sheets Sync
Export data to Google Sheets for additional analysis:
1. Use Airtable's native sync to Google Sheets
2. Or export CSV and import to Sheets

### Power BI / Tableau
Connect for advanced analytics:
1. Export data via API
2. Import into BI tool
3. Create custom dashboards

---

## Security & Access Control

### Workspace Permissions
- **Owner:** Full access to base and settings
- **Creator:** Can create and edit records
- **Editor:** Can edit existing records
- **Commenter:** Can comment only
- **Read-only:** Can view only

### API Key Security
- ✅ Store in environment variables (not in code)
- ✅ Use Personal Access Tokens (not API keys)
- ✅ Grant minimum required scopes
- ✅ Rotate tokens periodically
- ✅ Revoke tokens when no longer needed
- ❌ Never commit tokens to git
- ❌ Don't share tokens via email or chat

### Audit Trail
Airtable automatically tracks:
- Who created each record
- Who last modified each record
- Timestamp of changes
- View in record history

---

## Maintenance

### Weekly Tasks
- Review "Failures" view
- Check for processing bottlenecks
- Monitor average processing times

### Monthly Tasks
- Archive old records (>90 days)
- Review and optimize views
- Check API usage and limits
- Backup data

### Quarterly Tasks
- Review field structure
- Update views based on usage
- Audit access permissions
- Rotate API tokens

---

## Support Resources

- **Airtable Support:** https://support.airtable.com
- **API Documentation:** https://airtable.com/developers/web/api/introduction
- **Community Forum:** https://community.airtable.com
- **API Status:** https://status.airtable.com

---

## Next Steps

After Airtable is configured:

1. ✅ Create base and table
2. ✅ Set up all fields
3. ✅ Create views
4. ✅ Get API credentials
5. ✅ Configure MetaDataLogger Lambda
6. ✅ Test with sample record
7. ✅ Process first video end-to-end
8. ✅ Verify record appears in Airtable

---

For complete pipeline setup, refer to the main [README](../README.md).
