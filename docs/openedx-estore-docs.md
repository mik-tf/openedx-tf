# OpenedX E-commerce Setup Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [Deployment Process](#deployment-process)
   - [Step 1: Initial OpenedX Deployment](#step-1-initial-openedx-deployment)
   - [Step 2: Configure Backup System](#step-2-configure-backup-system)
   - [Step 3: Add E-commerce Functionality](#step-3-add-e-commerce-functionality)
5. [E-commerce Configuration](#e-commerce-configuration)
   - [Payment Processor Setup](#payment-processor-setup)
   - [Site Configuration](#site-configuration)
   - [OAuth2 Setup](#oauth2-setup)
6. [Course Monetization](#course-monetization)
   - [Setting Course Prices](#setting-course-prices)
   - [Configuring Course Modes](#configuring-course-modes)
7. [Testing E-commerce Functionality](#testing-e-commerce-functionality)
8. [Troubleshooting](#troubleshooting)
9. [Backup Considerations for E-commerce](#backup-considerations-for-e-commerce)
10. [Production Considerations](#production-considerations)
11. [Appendix: Reference Commands](#appendix-reference-commands)

## Introduction

This guide provides step-by-step instructions for setting up a complete OpenedX platform with e-commerce functionality on the ThreeFold Grid. The process includes:

1. Deploying the base OpenedX system
2. Configuring a robust backup solution
3. Adding and configuring the e-commerce service

The e-commerce service enables you to offer paid courses, accept payments through various payment processors, and manage financial transactions within your learning platform.

## Architecture Overview

When fully deployed, your system will have the following components:

- **OpenedX Core**: The main learning platform (LMS) and content management system (Studio)
- **Backup System**: Three-tier backup strategy with local, remote, and optional local computer storage
- **E-commerce Service**: Additional service enabling course sales and payment processing

## Prerequisites

- ThreeFold Full VM with Ubuntu 24.04
- At least 16GB RAM (recommended for production with e-commerce)
- At least 50GB storage
- IPv4 networking configured
- Domain name with ability to add subdomains
- For payments: Account with a supported payment processor (PayPal, Stripe, etc.)

## Deployment Process

### Step 1: Initial OpenedX Deployment

First, deploy the base OpenedX system using the automated deployment script:

```bash
# SSH into your ThreeFold grid node as root
ssh root@<your-vm-ip>

# Download the deployment script
wget https://raw.githubusercontent.com/mik-tf/openedx-tf/refs/heads/main/deploy.sh

# Make it executable and run it
chmod +x deploy.sh
./deploy.sh
```

This script will:
- Install system prerequisites
- Configure Docker with persistent storage
- Create an admin user (tutor)
- Install OpenedX using Tutor
- Configure basic security settings

During installation, you'll see instructions for:
- Adding your SSH key
- Activating the tutor environment
- Starting OpenedX services
- Adding DNS records

**Important**: Before proceeding, add the required DNS records:
- A record: `learn.yourdomain.com` pointing to your VM's IP
- CNAME record: `*.learn.yourdomain.com` pointing to `learn.yourdomain.com`

### Step 2: Configure Backup System

After the base system is deployed, configure the backup system:

1. Set up a separate VM for backup storage:
   ```bash
   # Copy the backup VM setup script
   scp docs-backup/backup-vm-setup.sh root@<backup-vm-ip>:~/

   # SSH into the backup VM and run the script
   ssh root@<backup-vm-ip>
   chmod +x backup-vm-setup.sh
   ./backup-vm-setup.sh
   ```

2. Configure your production VM to perform backups:
   ```bash
   # On your production VM
   sudo ./docs-backup/production-vm-backup-setup.sh
   ```

3. Copy the generated SSH key to your backup VM:
   ```bash
   # The key will be displayed after running the script
   # Copy it to the backup VM's authorized_keys
   ssh backup@<backup-vm-ip>
   echo "ssh-rsa AAAA..." >> ~/.ssh/authorized_keys
   ```

4. Update the backup script with your backup VM's IP:
   ```bash
   # On your production VM
   sudo nano /home/tutor/openedx-backup.sh
   # Find BACKUP_VM_IP and update it
   ```

5. Test the backup system:
   ```bash
   sudo -u tutor /home/tutor/openedx-backup.sh
   ```

### Step 3: Add E-commerce Functionality

Now that the core system and backups are configured, add e-commerce functionality:

```bash
# Login as tutor user
su - tutor

# Activate the virtual environment
source ~/tutor-env/bin/activate

# Install the ecommerce plugin
tutor plugins install ecommerce

# Apply the changes to the configuration
tutor config save
```

This installs the e-commerce plugin but additional configuration is needed before it can be used.

## E-commerce Configuration

### Payment Processor Setup

First, initialize and start the e-commerce service:

```bash
# Initialize the ecommerce service
tutor local do init --limit=ecommerce

# Start the ecommerce service
tutor local start ecommerce
```

Next, configure a payment processor. Create the configuration directory and file:

```bash
# Create configuration directory if it doesn't exist
mkdir -p "$(tutor config printroot)/env/plugins/ecommerce/apps/ecommerce/conf/"

# Create payment processor configuration
nano "$(tutor config printroot)/env/plugins/ecommerce/apps/ecommerce/conf/payment_processors.yml"
```

Add configuration for your chosen payment processor(s). Examples:

**PayPal Configuration:**
```yaml
paypal:
    MODE: sandbox  # Use "sandbox" for testing, "live" for production
    CLIENT_ID: your_paypal_client_id
    CLIENT_SECRET: your_paypal_client_secret
    CANCEL_URL: "https://ecommerce.yourdomain.com/checkout/cancel-checkout/"
    ERROR_URL: "https://ecommerce.yourdomain.com/checkout/error/"
    RECEIPT_URL: "https://ecommerce.yourdomain.com/checkout/receipt/"
```

**Stripe Configuration:**
```yaml
stripe:
    SECRET_KEY: your_stripe_secret_key
    PUBLISHABLE_KEY: your_stripe_publishable_key
    CANCEL_URL: "https://ecommerce.yourdomain.com/checkout/cancel-checkout/"
    ERROR_URL: "https://ecommerce.yourdomain.com/checkout/error/"
    RECEIPT_URL: "https://ecommerce.yourdomain.com/checkout/receipt/"
    COUNTRY: US
    APPLE_PAY_DOMAIN: ecommerce.yourdomain.com
```

### Site Configuration

Create a site configuration for the e-commerce service:

```bash
# Access the LMS Django shell
tutor local exec lms ./manage.py lms shell

# In the shell, run:
from django.contrib.sites.models import Site
from ecommerce.core.models import SiteConfiguration

# Get your LMS hostname
lms_host = Site.objects.get(name="LMS").domain

# Create the site for ecommerce
ecommerce_domain = "ecommerce." + ".".join(lms_host.split(".")[1:])
ecommerce_site, _ = Site.objects.get_or_create(domain=ecommerce_domain, defaults={"name": "Ecommerce"})

# Create the site configuration
SiteConfiguration.objects.create(
    site=ecommerce_site,
    partner="OpenEdX",
    lms_url_root="https://" + lms_host,
    payment_processors="paypal",  # Or other processors you've configured (comma-separated)
    client_side_payment_processor="",
    oauth_settings={
        "SOCIAL_AUTH_EDX_OIDC_KEY": "ecommerce-key",
        "SOCIAL_AUTH_EDX_OIDC_SECRET": "ecommerce-secret"
    }
)

# Exit the shell
exit()
```

### OAuth2 Setup

Create an OAuth2 client for the e-commerce service:

```bash
# Get your LMS hostname
LMS_HOST=$(tutor config printvalue LMS_HOST)

# Create OAuth2 client
tutor local exec lms ./manage.py lms create_oauth2_client \
    ecommerce ecommerce-secret \
    https://ecommerce.$LMS_HOST/complete/edx-oidc/ \
    --client_name ecommerce \
    --client_type confidential \
    --skip-authorization
```

### DNS Configuration

Add a new DNS record for the e-commerce service:

| Record Type | Host | Value | Comment |
|-------------|-----------|--------------|---------|
| A | ecommerce | Your VM's IP | Same IP as your main LMS |
| CNAME | ecommerce | learn.yourdomain.com | Alternative approach |

### Restart Services

Apply all changes and restart services:

```bash
# Restart all services
tutor local stop
tutor local start
```

## Course Monetization

### Setting Course Prices

To monetize courses, you need to configure course modes and pricing:

1. Log in as an administrator to your LMS (https://learn.yourdomain.com/admin/)
2. Navigate to Course Modes > Course Mode
3. Click "Add course mode" and fill in:
   - Course ID: your course ID (e.g., course-v1:YourOrg+YourCourse+YourRun)
   - Mode: verified
   - Currency: USD (or your preferred currency)
   - Min Price: Set your course price
   - Suggested Prices: Optional comma-separated list of suggested prices
   - Expiration Date: Optional date when enrollment closes
4. Save the course mode

### Configuring Course Modes

Enable course modes in Studio for each course you want to sell:

1. Go to Studio (https://cms.yourdomain.com/)
2. Open the course you want to sell
3. Go to "Settings" > "Advanced Settings"
4. Find "Enable Course Modes" and set it to `true`
5. Save changes

## Testing E-commerce Functionality

After configuring everything, test the e-commerce functionality:

1. Open your LMS (https://learn.yourdomain.com/)
2. Log in as a regular user (not admin)
3. Find a course with price configuration
4. Click "Enroll" and verify you're prompted to pay
5. Complete a test purchase using sandbox/test mode of your payment processor

## Troubleshooting

### Common Issues

1. **E-commerce service not starting**

   Check the logs for errors:
   ```bash
   tutor local logs ecommerce
   ```

2. **Payment processor not appearing**

   Verify your payment processor configuration:
   ```bash
   cat "$(tutor config printroot)/env/plugins/ecommerce/apps/ecommerce/conf/payment_processors.yml"
   ```

3. **Cannot access e-commerce dashboard**

   Check that your DNS records are correct and that the ecommerce service is running:
   ```bash
   tutor local status
   dig ecommerce.yourdomain.com
   ```

4. **OAuth errors during payment**

   Verify your OAuth client configuration:
   ```bash
   tutor local exec lms ./manage.py lms shell -c "from oauth2_provider.models import Application; print(Application.objects.filter(name='ecommerce').values())"
   ```

### Fixing Issues

If you encounter persistent problems:

1. Verify all services are running:
   ```bash
   tutor local status
   ```

2. Restart the ecommerce service:
   ```bash
   tutor local restart ecommerce
   ```

3. Rebuild the ecommerce image if needed:
   ```bash
   tutor images build ecommerce
   ```

4. Check for network issues:
   ```bash
   tutor local exec ecommerce ping -c 4 lms
   ```

## Backup Considerations for E-commerce

The e-commerce service stores data in the MySQL database, which is already covered by the backup system. However, consider these additional steps:

1. After adding e-commerce, create a full backup immediately:
   ```bash
   sudo -u tutor /home/tutor/openedx-backup.sh
   ```

2. If using production payment processors, consider more frequent backups:
   ```bash
   # Edit the tutor user's crontab to run twice daily
   sudo crontab -u tutor -e
   # Add: 0 3,15 * * * /home/tutor/openedx-backup.sh
   ```

3. Ensure your backup recovery procedure is tested with e-commerce enabled:
   ```bash
   # During recovery testing, verify e-commerce functionality:
   tutor local exec ecommerce ./manage.py check
   ```

## Production Considerations

Before going live with e-commerce:

1. **Security**: Ensure your server has the latest security updates
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **SSL**: Verify SSL is working properly for all domains
   ```bash
   curl -I https://ecommerce.yourdomain.com
   ```

3. **Monitoring**: Consider setting up monitoring for the e-commerce service
   ```bash
   # Basic monitoring script example
   echo '#!/bin/bash
   if ! curl -s https://ecommerce.yourdomain.com/health/ | grep -q "OK"; then
     echo "E-commerce service is down" | mail -s "Alert: E-commerce Down" admin@yourdomain.com
   fi' > /home/tutor/monitor-ecommerce.sh
   chmod +x /home/tutor/monitor-ecommerce.sh
   sudo crontab -u tutor -e
   # Add: */5 * * * * /home/tutor/monitor-ecommerce.sh
   ```

4. **Payment Processors**: Switch from sandbox/test mode to production mode in your payment processor configuration

5. **Financial Reporting**: Set up regular financial reporting
   ```bash
   tutor local exec ecommerce ./manage.py generate_orders_report --start="2023-01-01" --end="$(date +%Y-%m-%d)"
   ```

## Appendix: Reference Commands

### E-commerce Management Commands

```bash
# List available management commands
tutor local exec ecommerce ./manage.py help

# Check e-commerce system health
tutor local exec ecommerce ./manage.py check

# Create a superuser for e-commerce
tutor local exec ecommerce ./manage.py createsuperuser

# Generate financial reports
tutor local exec ecommerce ./manage.py generate_orders_report --start="YYYY-MM-DD" --end="YYYY-MM-DD"

# Refresh course metadata
tutor local exec ecommerce ./manage.py refresh_course_metadata
```

### Backup and Restore with E-commerce

```bash
# Create a backup including e-commerce data
tutor local backup

# Restore a backup with e-commerce data
tutor local restore /path/to/backup.tar.gz

# Initialize only the e-commerce service after restore
tutor local do init --limit=ecommerce
```

### Service Management

```bash
# Check status of all services including e-commerce
tutor local status

# Restart only the e-commerce service
tutor local restart ecommerce

# View e-commerce logs
tutor local logs ecommerce

# Enter e-commerce container shell
tutor local exec ecommerce bash
```

This comprehensive guide covers the full process of setting up an OpenedX instance with e-commerce functionality on the ThreeFold Grid, from initial deployment through backup configuration and e-commerce setup. Follow these steps in sequence to create a complete, production-ready learning platform with payment capabilities.
