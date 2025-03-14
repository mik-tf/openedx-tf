<h1> OpenedX Deployment on the ThreeFold Grid </h1>

<h2>Table of Contents</h2>

- [Introduction](#introduction)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [ThreeFold Grid Deployment](#threefold-grid-deployment)
- [Quick Start](#quick-start)
- [Post-Installation](#post-installation)
  - [DNS Configuration](#dns-configuration)
- [Backup and Recovery](#backup-and-recovery)
  - [Setting Up Backups](#setting-up-backups)
  - [Disaster Recovery](#disaster-recovery)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [Security Notes](#security-notes)
- [License](#license)
- [About ThreeFold](#about-threefold)
- [About OpenedX](#about-openedx)

---

## Introduction

This repository contains an automated deployment script for setting up an OpenedX learning platform on a ThreeFold grid node. The script automates the installation of Docker, Tutor (the official OpenedX deployment tool), and all necessary dependencies for running a production-ready OpenedX instance.

## Features

- **Fully Automated Setup**: Non-interactive deployment that can be run as part of VM initialization
- **Security-Focused**: Creates a secure admin user, configures SSH key-based authentication, and sets up a firewall
- **Persistent Storage**: Configures Docker to use dedicated storage on `/dev/vda` to ensure data survives reboots
- **OpenedX with Tutor**: Installs Tutor, the official and recommended way to deploy OpenedX
- **Indigo Theme**: Includes the Indigo theme for a modern learning experience
- **Comprehensive Backup System**: Three-tier backup strategy with offsite storage
- **Disaster Recovery**: Complete recovery process documented
- **Production-Ready**: Includes all necessary configurations for a production environment

## Prerequisites

- A ThreeFold Full VM with Ubuntu 24.04 and IPv4 network
- At least 8GB RAM (16GB recommended for production)
- At least 50GB storage
- SSH access to the node with root privileges
- For backups: A second VM to serve as backup storage

## ThreeFold Grid Deployment

This deployment is specifically designed to run on a **Full Virtual Machine** on the ThreeFold Grid with:
- IPv4 networking enabled
- Public IPv4 address assigned to the VM
- Additional disk with at least 50GB of storage
- Ubuntu 24.04 LTS as the base operating system

For instructions on deploying a Full VM on the ThreeFold Grid, refer to the [ThreeFold Manual](https://manual.grid.tf/).

## Quick Start

1. SSH into your ThreeFold grid node as root
2. Download the deployment script and run it:
   ```bash
   wget https://raw.githubusercontent.com/mik-tf/openedx-tf/refs/heads/main/scripts/deployment/deploy.sh
   bash deploy.sh
   ```
3. Follow the post-installation instructions displayed at the end of the script output

## Post-Installation

After successful deployment, you can log in as the `tutor` user via SSH and launch the platform:

- Change user
   ```
   su - tutor
   ```
- Launch Tutor
   ```
   source ~/tutor-env/bin/activate
   tutor local launch
   ```
- Update and install a theme
   ```
   tutor plugins update
   tutor plugins install indigo
   ```

### DNS Configuration

To properly access your OpenedX instance, you need to configure DNS records pointing to your VM's IPv4 address.

1. Set up an A record pointing your main domain (e.g., `learn.yourdomain.com`) to your VM's IPv4 address
2. Set up a wildcard CNAME record (`*.learn.yourdomain.com`) pointing to your main domain

For example, if your domain is `domain.com` and you want the school to be hosted at the subdomain `learn.yourdomain.com`, you would have the following:

**Example DNS Configuration:**

| Record Type | Host | Value | Comment |
|-------------|-----------|--------------|---------|
| A | learn | 192.168.1.100 | Replace with your VM's actual IPv4 address |
| CNAME | *.learn | learn.yourdomain.com | Wildcard record for all subdomains |

This configuration ensures that both the main LMS platform and subdomains for Studio (cms.learn.yourdomain.com) and other services work correctly. After configuring DNS, the platform will be accessible at `https://learn.yourdomain.com` and Studio at `https://cms.learn.yourdomain.com`.

## Backup and Recovery

This repository includes a comprehensive backup and disaster recovery system for your OpenedX installation.

### Setting Up Backups

The backup system follows a three-tier approach:

1. **Production VM**: Daily backups stored locally
2. **Backup VM**: Offsite backup storage with longer retention
3. **Local Computer**: Manual download option for critical backups

To set up the backup system:

1. Deploy a second VM to serve as your backup server:
   ```bash
   scp scripts/backup/backup-vm-setup.sh root@<backup-vm-ip>:~/
   ssh root@<backup-vm-ip> "chmod +x ~/backup-vm-setup.sh && ./backup-vm-setup.sh"
   ```

2. Configure backup on your production VM:
   ```bash
   sudo ./scripts/backup/production-vm-backup-setup.sh
   ```

3. Follow the displayed instructions to complete the setup:
   - Copy the SSH key to your backup VM
   - Update the backup script with your backup VM's IP
   - Test the backup system

For detailed instructions, refer to the [backup documentation](docs/backup/README.md).

### Disaster Recovery

If you need to recover your OpenedX installation:

1. Deploy a new VM using the main deployment script
2. Obtain the latest backup (from backup VM or local copy)
3. Follow the step-by-step instructions in the [recovery guide](docs/backup/recovery-guide.md)

The recovery process is designed to minimize downtime and ensure complete restoration of your OpenedX environment.

## Customization

You can customize the deployment by editing the script variables at the top:

- `NEW_USER`: The name of the admin user (default: `tutor`)
- `USER_PASSWORD`: The password for the admin user (default: `tutorpassword`)

For OpenedX customization options:

- Theme customization: `tutor config printvalue THEME_NAME`
- Platform name: `tutor config printvalue PLATFORM_NAME`
- Additional plugins: `tutor plugins list`

## Troubleshooting

If you encounter issues during deployment:

- Check Docker status: `systemctl status docker`
- Review Tutor logs: `tutor local logs`
- Verify firewall configuration: `iptables -L -v`
- Check Docker data directory location: `docker info | grep "Docker Root Dir"`
- Verify IPv4 connectivity: `curl -4 ifconfig.co`

For backup-related issues:

- Check backup logs: `cat /home/tutor/backup.log`
- Verify SSH connectivity: `sudo -u tutor ssh -i /home/tutor/.ssh/backup_id_rsa backup@<backup-vm-ip>`
- Check disk space: `df -h`

## Security Notes

- The script disables SSH password authentication by default, requiring key-based login
- The created admin user has passwordless sudo access for ease of administration
- A basic iptables firewall is configured to allow only necessary traffic
- Backup transfers use SSH encryption for security
- The backup system uses dedicated SSH keys with restricted permissions

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## About ThreeFold

ThreeFold is a peer-to-peer internet infrastructure that aims to create a more sustainable, private, and secure internet. Learn more at [threefold.io](https://threefold.io).

## About OpenedX

Open edX is the open-source platform that powers edX courses and is used by many organizations to host their own instances of the platform. Learn more at [open.edx.org](https://open.edx.org/).
