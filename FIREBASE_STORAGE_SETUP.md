# Firebase Storage Setup Guide

## Overview
This document explains how to set up Firebase Storage buckets for each environment (dev, test, prod) and configure CORS for web image access.

## Environment Details

| Environment | Project ID | Storage Bucket |
|-------------|------------|----------------|
| Development | f2c-dev-ddd82 | f2c-dev-ddd82.appspot.com |
| Test | f2c-test | f2c-test.firebasestorage.app |
| Production | f2c-prod | f2c-prod.firebasestorage.app |

## Step 1: Create Storage Buckets

### Development (Already Done)
The development bucket was created during initial project setup.

### Test Environment
1. Go to: https://console.firebase.google.com/project/f2c-test/storage
2. Click **"Get Started"**
3. Select **"Start in Test Mode"** (allows public read/write for development)
4. Choose location: `asia-south1` (or match your Firestore location)
5. Click **"Done"**

### Production Environment
1. Go to: https://console.firebase.google.com/project/f2c-prod/storage
2. Click **"Get Started"**
3. Select **"Start in Production Mode"** (recommended for security)
4. Choose location: `asia-south1` (must match Firestore location)
5. Click **"Done"**

## Step 2: Deploy Storage Rules

Storage rules are defined in `storage.rules` file in the project root.

### Deploy to Development
```bash
firebase deploy --only storage --project f2c-dev-ddd82
```

### Deploy to Test
```bash
firebase deploy --only storage --project f2c-test
```

### Deploy to Production
```bash
firebase deploy --only storage --project f2c-prod
```

## Step 3: Configure CORS

CORS (Cross-Origin Resource Sharing) is required for the web app to access images from Firebase Storage.

### CORS Configuration File
The `cors.json` file in the project root contains:
```json
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD", "PUT", "POST", "DELETE"],
    "maxAgeSeconds": 3600,
    "responseHeader": ["Content-Type", "Authorization", "Content-Length", "User-Agent", "X-Requested-With"]
  }
]
```

### Install gsutil (if not already installed)
```bash
# Using pip
pip install gsutil

# Or using Google Cloud SDK
# Download from: https://cloud.google.com/sdk/docs/install
```

### Authenticate with Google Cloud
```bash
gcloud auth login
```

### Deploy CORS Configuration

#### Development
```bash
gsutil cors set cors.json gs://f2c-dev-ddd82.appspot.com
```

#### Test
```bash
gsutil cors set cors.json gs://f2c-test.firebasestorage.app
```

#### Production
```bash
gsutil cors set cors.json gs://f2c-prod.firebasestorage.app
```

### Verify CORS Configuration
```bash
# Check CORS settings for a bucket
gsutil cors get gs://f2c-prod.firebasestorage.app
```

## Step 4: Storage Rules Overview

The `storage.rules` file defines access control:

### Key Rules:
- **Product Images**: Public read, authenticated write/delete
- **User Profile Images**: Owner or admin write, authenticated read
- **Farmer Images**: Admin write, authenticated read
- **Order Documents**: Admin write, authenticated read

### Security Features:
- Image size limit: 5MB
- Content type validation: Only images allowed
- Authentication required for most operations

## Troubleshooting

### 403 Forbidden Errors
- Cause: Storage rules not deployed or too restrictive
- Solution: Deploy storage rules using the commands above

### CORS Errors
- Cause: CORS not configured on the bucket
- Solution: Deploy CORS configuration using gsutil

### Upload Failures
- Check user is authenticated
- Verify file size is under 5MB
- Ensure content type is an image type

## Deployment Scripts

The deployment scripts (`deploy_dev.bat`, `deploy_test.bat`, `deploy_prod.bat`) automatically deploy storage rules. However, CORS must be configured manually using gsutil.

## Maintenance

### Updating Storage Rules
1. Edit `storage.rules` file
2. Deploy to all environments:
   ```bash
   firebase deploy --only storage --project f2c-dev-ddd82
   firebase deploy --only storage --project f2c-test
   firebase deploy --only storage --project f2c-prod
   ```

### Updating CORS Configuration
1. Edit `cors.json` file
2. Deploy to all buckets:
   ```bash
   gsutil cors set cors.json gs://f2c-dev-ddd82.appspot.com
   gsutil cors set cors.json gs://f2c-test.firebasestorage.app
   gsutil cors set cors.json gs://f2c-prod.firebasestorage.app
   ```

## References
- Firebase Storage Documentation: https://firebase.google.com/docs/storage
- CORS Configuration: https://cloud.google.com/storage/docs/cross-origin
- Firebase CLI: https://firebase.google.com/docs/cli
