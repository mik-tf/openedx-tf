#!/bin/bash
# Local backup downloader for OpenedX
set -e

# Check if IP address was provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <backup-vm-ip>"
    echo "Example: $0 123.45.67.89"
    exit 1
fi

# Configuration
BACKUP_VM_IP="$1"
BACKUP_VM_USER="backup"
LOCAL_DIR="$HOME/openedx_backups"
REMOTE_DIR="/backup/openedx"

# Create local directories
mkdir -p $LOCAL_DIR/{daily,weekly,monthly}

echo "Downloading OpenedX backups from backup server at $BACKUP_VM_IP..."

# Download the latest backup from each category
for category in daily weekly monthly; do
  echo "Downloading latest $category backup..."
  
  # Get latest file name
  latest=$(ssh $BACKUP_VM_USER@$BACKUP_VM_IP "ls -t $REMOTE_DIR/$category | head -1")
  
  if [ -n "$latest" ]; then
    # Download the file
    scp $BACKUP_VM_USER@$BACKUP_VM_IP:$REMOTE_DIR/$category/$latest $LOCAL_DIR/$category/
    echo "✅ Downloaded $category backup: $latest"
  else
    echo "No $category backups found"
  fi
done

echo "Backup download complete. Files saved to $LOCAL_DIR"
