# OpenedX Three-Tier Backup System

This directory contains all the scripts and documentation needed to set up a comprehensive backup system for your OpenedX installation.

## System Architecture

```
┌───────────────────┐    ┌───────────────────┐    ┌───────────────────┐
│                   │    │                   │    │                   │
│   Production VM   │───▶│    Backup VM      │◀───│   Local Computer  │
│                   │    │                   │    │                   │
└───────────────────┘    └───────────────────┘    └───────────────────┘
      Daily backups         Offsite storage          Manual downloads
      7-day retention       30-day retention         As needed
```

## Complete Setup Process

### Step 1: Set up your Backup VM

First, set up a dedicated VM to store your backups:

1. Deploy a new VM with Ubuntu that will serve as your backup server
2. Copy the backup VM setup script to the server:
   ```bash
   scp scripts/backup/backup-vm-setup.sh root@<backup-vm-ip>:~/
   ```
3. SSH into the backup VM and run the setup script:
   ```bash
   ssh root@<backup-vm-ip>
   chmod +x backup-vm-setup.sh
   ./backup-vm-setup.sh
   ```
4. **IMPORTANT**: Note down the IP address of your backup VM. You will need it in the next step.

### Step 2: Configure Your Production VM

Next, set up the backup system on your production OpenedX VM:

1. Make sure your OpenedX instance is already deployed and working properly
2. Run the production VM backup setup script:
   ```bash
   sudo ./scripts/backup/production-vm-backup-setup.sh
   ```
3. **IMPORTANT**: The script will generate an SSH key and display it. Copy this key.
4. On your backup VM, add the SSH key to the authorized keys:
   ```bash
   ssh backup@<backup-vm-ip>
   echo "ssh-rsa AAAA..." >> ~/.ssh/authorized_keys
   # Paste the key shown by the production setup script
   ```
5. **IMPORTANT**: Edit the backup script on your production VM to set your backup VM's IP:
   ```bash
   sudo nano /home/tutor/openedx-backup.sh
   ```
   Find the line `BACKUP_VM_IP="your-backup-vm-ip-here"` and replace with your actual backup VM IP.

### Step 3: Test the Backup System

Verify that the backup system is working correctly:

1. On your production VM, manually run the backup script:
   ```bash
   sudo -u tutor /home/tutor/openedx-backup.sh
   ```
2. Verify the backup was created locally:
   ```bash
   ls -la /home/tutor/openedx_backups/daily/
   ```
3. Verify the backup was transferred to your backup VM:
   ```bash
   ssh backup@<backup-vm-ip> "ls -la /backup/openedx/daily/"
   ```

### Step 4: Configure Local Backup Downloads (Optional)

To download backups to your local machine:

1. Copy the local backup puller script to your local computer
2. Run the script with your backup VM's IP:
   ```bash
   ./scripts/backup/local-backup-puller.sh <backup-vm-ip>
   ```
3. Enter the password for the backup user when prompted
4. Verify the backups were downloaded:
   ```bash
   ls -la ~/openedx_backups/
   ```

## Recovery Process

If disaster strikes and you need to restore your OpenedX instance:

1. Deploy a new VM using the main deployment script
2. Follow the detailed instructions in [recovery-guide.md](recovery-guide.md)

## Retention Policies

The backup system automatically manages retention according to these policies:

- **Production VM**:
  - Daily: 7 days
  - Weekly: 4 weeks
  - Monthly: 3 months

- **Backup VM**:
  - Daily: 30 days
  - Weekly: 90 days (3 months)
  - Monthly: 365 days (1 year)

## Detailed Script Descriptions

### backup-vm-setup.sh

This script prepares a dedicated VM to serve as your backup storage server:

- Creates a `backup` user
- Sets up directory structure for backups
- Configures disk space monitoring
- Prepares SSH configuration for secure transfers

**After running the script**:
1. You must manually add the SSH public key from your production server
2. Ensure `/backup` has sufficient storage space (at least 100GB recommended)
3. Verify network connectivity between production and backup VMs

### production-vm-backup-setup.sh

This script configures your OpenedX production server to perform regular backups:

- Creates a backup script in `/home/tutor/openedx-backup.sh`
- Generates an SSH key for secure transfers
- Sets up a cron job for daily backups
- Configures local retention policies

**Manual configuration required after running**:
1. Add the generated SSH key to your backup VM's authorized_keys
2. Edit the backup script to update `BACKUP_VM_IP` with your actual backup VM IP
3. Verify the SSH key has the right permissions (600)

### local-backup-puller.sh

This script allows you to download backups from your backup VM to your local computer:

- Downloads the latest daily, weekly, and monthly backups
- Creates local directories to organize backups
- Uses SSH for secure transfers

**Usage requirements**:
1. SSH access to your backup VM (with password or key)
2. The backup VM's IP address
3. Sufficient local disk space for backups

## Understanding the Backup Types

The system creates three types of backups:

1. **Daily backups**: Created every day at 3 AM
   - Stored on production VM for 7 days
   - Stored on backup VM for 30 days

2. **Weekly backups**: Created every Sunday
   - Same file as the daily backup, but copied to weekly directory
   - Stored on production VM for 4 weeks
   - Stored on backup VM for 90 days

3. **Monthly backups**: Created on the 1st of each month
   - Same file as the daily backup, but copied to monthly directory
   - Stored on production VM for 3 months
   - Stored on backup VM for 365 days

## Troubleshooting

### SSH Connection Issues

If the backup script cannot connect to the backup VM:

1. Verify you can manually SSH to the backup VM:
   ```bash
   sudo -u tutor ssh -i /home/tutor/.ssh/backup_id_rsa backup@<backup-vm-ip>
   ```
2. Verify the backup user has correct permissions:
   ```bash
   ls -la /home/tutor/.ssh/backup_id_rsa
   ```
   Permissions should be `-rw-------` (600)

### Backup Script Failures

If the backup script fails:

1. Check the backup log on the production VM:
   ```bash
   cat /home/tutor/backup.log
   ```
2. Verify disk space on both VMs:
   ```bash
   df -h
   ```

## Security Considerations

The backup system is designed with security in mind:

- Uses SSH key-based authentication (not passwords)
- Transfers are encrypted through SSH
- The backup VM should ideally be in a separate security zone
- No public services need to be exposed on the backup VM

**Recommended practices**:
1. Use a firewall to restrict access to the backup VM (allow only SSH from production VM)
2. Rotate SSH keys periodically
3. Monitor the backup logs for unauthorized access attempts

## Monitoring Backup Health

To ensure your backups are working properly:

1. Check backup logs daily:
   ```bash
   cat /home/tutor/backup.log | grep "completed successfully"
   ```

2. Verify backup sizes are consistent:
   ```bash
   du -sh /home/tutor/openedx_backups/daily/
   ```

3. Set up email alerts for backup failures by modifying the backup script to send notifications

4. Regularly test the restore process on a temporary VM

## Customizing Backup Schedules

By default, backups run daily at 3 AM. To change this:

1. Edit the crontab for the tutor user:
   ```bash
   sudo crontab -u tutor -e
   ```
2. Modify the timing according to crontab syntax:
   ```
   # Format: minute hour day-of-month month day-of-week command
   0 3 * * * /home/tutor/openedx-backup.sh
   ```

## Appendix: Quick Reference Commands

### Manually trigger a backup
```bash
sudo -u tutor /home/tutor/openedx-backup.sh
```

### Check backup status
```bash
cat /home/tutor/backup.log | tail -50
```

### Verify backup transfers
```bash
ssh backup@<backup-vm-ip> "ls -la /backup/openedx/daily/"
```

### Download a specific backup file
```bash
scp backup@<backup-vm-ip>:/backup/openedx/daily/filename.tar.gz ./
```

### Test SSH connectivity
```bash
sudo -u tutor ssh -i /home/tutor/.ssh/backup_id_rsa backup@<backup-vm-ip> "echo Connection successful"
```
