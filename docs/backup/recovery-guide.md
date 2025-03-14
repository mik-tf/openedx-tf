# OpenedX Disaster Recovery Guide

This guide provides detailed step-by-step instructions for recovering your OpenedX installation in case of VM failure or data loss.

## Prerequisites

Before beginning the recovery process, ensure you have:

- Access to your backup files (from backup VM or local machine)
- A new VM with similar or better specs compared to your original VM
- SSH access to the new VM with root privileges
- Your domain name and DNS access credentials
- At least 30 minutes of uninterrupted time

## Recovery Workflow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  Deploy New VM  │────▶│ Restore Backup  │────▶│ Verify & Update │
│                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Step 1: Deploy a New VM

First, deploy a fresh VM and install the OpenedX base system:

```bash
# On your local computer
scp deploy.sh root@<new-vm-ip>:~/
ssh root@<new-vm-ip>

# On the new VM
chmod +x deploy.sh
./deploy.sh
```

Wait for the deployment script to complete. This typically takes 15-30 minutes depending on VM specs.

## Step 2: Obtain the Latest Backup

You have two options for obtaining the latest backup:

### Option A: Get backup directly from backup VM

```bash
# SSH into the new VM
ssh root@<new-vm-ip>

# Create a directory for the backup
mkdir -p /tmp/backup

# Download from backup VM (backup user)
scp backup@<backup-vm-ip>:/backup/openedx/daily/$(ssh backup@<backup-vm-ip> "ls -t /backup/openedx/daily | head -1") /tmp/backup/
```

### Option B: Transfer from your local machine

If you've already downloaded backups to your local machine:

```bash
# From your local computer
scp ~/openedx_backups/daily/$(ls -t ~/openedx_backups/daily | head -1) root@<new-vm-ip>:/tmp/backup/
```

## Step 3: Restore the OpenedX Instance

Now restore the OpenedX installation from your backup:

```bash
# On the new VM
# Switch to tutor user
su - tutor

# Set up environment
export PATH="$HOME/tutor-env/bin:$PATH"

# First, stop any running services
tutor local stop

# Find the backup file
BACKUP_FILE=$(ls -t /tmp/backup/*.tar.gz | head -1)
echo "Using backup file: $BACKUP_FILE"

# Perform the restore
tutor local restore $BACKUP_FILE

# Start the services
tutor local start

# Update plugins if necessary
tutor plugins update
tutor plugins list

# If you were using the Indigo theme, reinstall it
tutor plugins install indigo
tutor local restart
```

## Step 4: Verify the Restored Instance

Before proceeding, verify that the restoration was successful:

```bash
# Check if all services are running
tutor local status

# Check the logs for any errors
tutor local logs

# Access the platform locally using the LMS host
echo "LMS host is set to: $(tutor config printvalue LMS_HOST)"
```

Manually check these critical functions:
- User login (admin account)
- Course content display
- User enrollment
- Video playback (if applicable)
- Any custom plugins or themes

## Step 5: Update DNS Records

Once you've verified the restored instance is working properly, update your DNS records:

1. Find the new VM's IP address:
   ```bash
   curl -4 ifconfig.co
   ```

2. Update your DNS A record to point to this new IP address:
   | Record Type | Name | Value |
   |-------------|------|-------|
   | A | learn (or your subdomain) | <new-vm-ip> |
   | CNAME | *.learn (or your subdomain) | learn.yourdomain.com |

3. Verify DNS propagation (this may take some time):
   ```bash
   dig +short learn.yourdomain.com
   ```

## Step 6: Restore the Backup System

Finally, set up the backup system on your new VM:

```bash
# As root user on new VM
sudo ./scripts/backup/production-vm-backup-setup.sh
```

Follow the instructions displayed after running the script to:
1. Copy the generated SSH key to your backup VM
2. Update the backup script with your backup VM's IP address
3. Test the backup system

## Step 7: Post-Recovery Tasks

After the main recovery is complete:

1. Update any monitoring systems with the new VM's details
2. Notify users if there was any downtime
3. Consider scheduling a full backup immediately to verify the backup system

## Troubleshooting Common Recovery Issues

### MySQL Database Errors

If you encounter database-related errors:

```bash
# Check MySQL logs
tutor local logs mysql

# Verify database connectivity
tutor local exec lms ./manage.py lms shell -c "from django.db import connection; connection.ensure_connection(); print('Connection successful')"

# If needed, reinitialize the database (caution: only as last resort)
tutor local init --limit mysql
```

### Missing Course Content

If course content appears to be missing after restore:

```bash
# Check if course data exists in the backup
mkdir -p /tmp/backup_check
tar -xzf $BACKUP_FILE -C /tmp/backup_check
ls -la /tmp/backup_check/mongodb/dump/openedx/

# Reimport a specific course if needed (replace with actual course ID)
tutor local exec cms ./manage.py cms import /path/to/course/export.tar.gz
```

### Container Startup Issues

If containers fail to start properly:

```bash
# Check container status
tutor local status

# Inspect specific container logs
tutor local logs <container-name>

# Try rebuilding images
tutor images build openedx
tutor local restart
```

### SSL/HTTPS Issues

If SSL certificates aren't working correctly:

```bash
# Check if Let's Encrypt certificates are being generated
tutor local logs caddy

# Force certificate renewal
tutor local exec caddy caddy reload
```

## Recovery Time Estimates

| Step | Estimated Time |
|------|----------------|
| Deploy new VM | 15-30 minutes |
| Transfer backup | 5-15 minutes (depends on size) |
| Restore backup | 10-20 minutes |
| Verification | 5-10 minutes |
| DNS propagation | 5 minutes - 48 hours |
| Total | 35 minutes - 2+ hours |
