#!/bin/bash
set -e

# Backup VM setup script for OpenedX
echo "======== Setting up OpenedX Backup Server ========"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Install prerequisites
export DEBIAN_FRONTEND=noninteractive
apt update && apt install -y openssh-server rsync sudo

# Create backup user
BACKUP_USER="backup"
useradd -m -s /bin/bash "$BACKUP_USER" 2>/dev/null || echo "User already exists"

# Create backup directories
BACKUP_DIR="/backup/openedx"
mkdir -p $BACKUP_DIR/{daily,weekly,monthly}
chown -R $BACKUP_USER:$BACKUP_USER $BACKUP_DIR

# Set up SSH directory
mkdir -p /home/$BACKUP_USER/.ssh
touch /home/$BACKUP_USER/.ssh/authorized_keys
chmod 700 /home/$BACKUP_USER/.ssh
chmod 600 /home/$BACKUP_USER/.ssh/authorized_keys
chown -R $BACKUP_USER:$BACKUP_USER /home/$BACKUP_USER/.ssh

# Create monitoring script
cat > /home/$BACKUP_USER/monitor-space.sh << 'EEOF'
#!/bin/bash
BACKUP_DIR="/backup/openedx"
THRESHOLD=85
USAGE=$(df -h $BACKUP_DIR | grep -v Filesystem | awk '{print $5}' | sed 's/%//')
if [ $USAGE -gt $THRESHOLD ]; then
  echo "Warning: Backup storage at $USAGE% capacity" | mail -s "OpenedX Backup Space Alert" root
fi
EEOF

chmod +x /home/$BACKUP_USER/monitor-space.sh
chown $BACKUP_USER:$BACKUP_USER /home/$BACKUP_USER/monitor-space.sh

# Set up cron job
(crontab -u $BACKUP_USER -l 2>/dev/null || echo "") | { cat; echo "0 7 * * * /home/$BACKUP_USER/monitor-space.sh"; } | crontab -u $BACKUP_USER -

echo "========================================================"
echo "Backup server is set up!"
echo ""
echo "NEXT STEP: Add the SSH key from your production server to:"
echo "/home/$BACKUP_USER/.ssh/authorized_keys"
echo ""
echo "You'll generate this key on your production server in the next step."
echo "========================================================"
