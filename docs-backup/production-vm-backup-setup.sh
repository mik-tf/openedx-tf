#!/bin/bash
set -e

# Production VM backup setup script for OpenedX
echo "======== Setting up OpenedX Backup System ========"

# Check if tutor user exists
if ! id -u tutor &>/dev/null; then
    echo "Error: tutor user not found. Please run the main deployment script first."
    exit 1
fi

# Create backup script
cat > /home/tutor/openedx-backup.sh << 'EEOF'
#!/bin/bash
set -e

# Configuration - UPDATE THESE VALUES
BACKUP_VM_IP="your-backup-vm-ip-here"  # CHANGE THIS!
BACKUP_VM_USER="backup"
BACKUP_SSH_KEY="/home/tutor/.ssh/backup_id_rsa"
LOCAL_BACKUP_DIR="/home/tutor/openedx_backups"
REMOTE_BACKUP_DIR="/backup/openedx"
LOG_FILE="/home/tutor/backup.log"

# Create directories if they don't exist
mkdir -p $LOCAL_BACKUP_DIR/{daily,weekly,monthly}

# Log function
log() {
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $1" | tee -a $LOG_FILE
}

log "Starting backup process"

# Set timestamp and determine backup type
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
DAY_OF_WEEK=$(date +%u)
DAY_OF_MONTH=$(date +%d)
BACKUP_FILE="openedx_backup_$TIMESTAMP.tar.gz"

# Run tutor backup
export PATH="/home/tutor/tutor-env/bin:$PATH"
log "Creating backup with tutor"
tutor config save
tutor local backup > $LOCAL_BACKUP_DIR/daily/$BACKUP_FILE

# Create weekly backup (on Sunday)
if [ "$DAY_OF_WEEK" -eq 7 ]; then
    log "Creating weekly backup"
    cp $LOCAL_BACKUP_DIR/daily/$BACKUP_FILE $LOCAL_BACKUP_DIR/weekly/
fi

# Create monthly backup (on 1st day of month)
if [ "$DAY_OF_MONTH" -eq "01" ]; then
    log "Creating monthly backup"
    cp $LOCAL_BACKUP_DIR/daily/$BACKUP_FILE $LOCAL_BACKUP_DIR/monthly/
fi

# Transfer to backup VM
log "Transferring backup to $BACKUP_VM_IP"
ssh -i $BACKUP_SSH_KEY -o StrictHostKeyChecking=no $BACKUP_VM_USER@$BACKUP_VM_IP "mkdir -p $REMOTE_BACKUP_DIR/{daily,weekly,monthly}" || {
    log "ERROR: Could not connect to backup VM. Check IP and SSH key."
    exit 1
}

# Transfer daily backup
scp -i $BACKUP_SSH_KEY $LOCAL_BACKUP_DIR/daily/$BACKUP_FILE $BACKUP_VM_USER@$BACKUP_VM_IP:$REMOTE_BACKUP_DIR/daily/

# Transfer weekly/monthly if applicable
if [ "$DAY_OF_WEEK" -eq 7 ]; then
    scp -i $BACKUP_SSH_KEY $LOCAL_BACKUP_DIR/daily/$BACKUP_FILE $BACKUP_VM_USER@$BACKUP_VM_IP:$REMOTE_BACKUP_DIR/weekly/
fi

if [ "$DAY_OF_MONTH" -eq "01" ]; then
    scp -i $BACKUP_SSH_KEY $LOCAL_BACKUP_DIR/daily/$BACKUP_FILE $BACKUP_VM_USER@$BACKUP_VM_IP:$REMOTE_BACKUP_DIR/monthly/
fi

# Apply retention policies
log "Applying retention policies"
# Keep 7 daily backups locally
find $LOCAL_BACKUP_DIR/daily -type f -mtime +7 -delete
# Keep 4 weekly backups locally
find $LOCAL_BACKUP_DIR/weekly -type f -mtime +28 -delete
# Keep 3 monthly backups locally
find $LOCAL_BACKUP_DIR/monthly -type f -mtime +90 -delete

# Apply remote retention policies
ssh -i $BACKUP_SSH_KEY $BACKUP_VM_USER@$BACKUP_VM_IP "
find $REMOTE_BACKUP_DIR/daily -type f -mtime +30 -delete;
find $REMOTE_BACKUP_DIR/weekly -type f -mtime +90 -delete;
find $REMOTE_BACKUP_DIR/monthly -type f -mtime +365 -delete;
"

log "Backup completed successfully"
EEOF

# Make script executable
chmod +x /home/tutor/openedx-backup.sh
chown tutor:tutor /home/tutor/openedx-backup.sh

# Generate SSH key for backup user
sudo -u tutor ssh-keygen -t rsa -b 4096 -f /home/tutor/.ssh/backup_id_rsa -N ""

# Create cron job for daily backups at 3 AM
(crontab -u tutor -l 2>/dev/null || echo "") | { cat; echo "0 3 * * * /home/tutor/openedx-backup.sh"; } | crontab -u tutor -

echo "========================================================"
echo "Backup system setup complete!"
echo ""
echo "IMPORTANT: You need to manually copy this SSH public key to your backup VM:"
echo ""
cat /home/tutor/.ssh/backup_id_rsa.pub
echo ""
echo "Add this key to: /home/backup/.ssh/authorized_keys on your backup VM"
echo ""
echo "Then edit /home/tutor/openedx-backup.sh to update BACKUP_VM_IP with your actual backup VM IP"
echo ""
echo "You can test the backup by running: sudo -u tutor /home/tutor/openedx-backup.sh"
echo "========================================================"
