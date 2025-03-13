<h1> OpenedX Deployment on the ThreeFold Grid </h1>

<h2>Table of Contents</h2>

- [Introduction](#introduction)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [ThreeFold Grid Deployment](#threefold-grid-deployment)
- [Quick Start](#quick-start)
- [Post-Installation](#post-installation)
  - [DNS Configuration](#dns-configuration)
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
- **Production-Ready**: Includes all necessary configurations for a production environment

## Prerequisites

- A ThreeFold Full VM with Ubuntu 24.04 and IPv4 network
- At least 8GB RAM (16GB recommended for production)
- At least 50GB storage
- SSH access to the node with root privileges

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
   wget https://raw.githubusercontent.com/mik-tf/openedx-tf/refs/heads/main/deploy.sh
   bash deploy.sh
   ```
3. Follow the post-installation instructions displayed at the end of the script output

## Post-Installation

After successful deployment, you can log in as the `tutor` user via SSH and launch the platform:

```
su - tutor
source ~/tutor-env/bin/activate
tutor plugins update
tutor plugins install indigo
tutor local launch
```

### DNS Configuration

To properly access your OpenedX instance, you need to configure DNS records pointing to your VM's IPv4 address:

1. Set up an A record pointing your main domain (e.g., `learn.yourdomain.com`) to your VM's IPv4 address
2. Set up a wildcard CNAME record (`*.learn.yourdomain.com`) pointing to your main domain

**Example DNS Configuration:**

| Record Type | Host/Name | Value/Target | Comment |
|-------------|-----------|--------------|---------|
| A | learn.yourdomain.com | 192.168.1.100 | Replace with your VM's actual IPv4 address |
| CNAME | *.learn.yourdomain.com | learn.yourdomain.com | Wildcard record for all subdomains |

This configuration ensures that both the main LMS platform and subdomains for Studio (cms.learn.yourdomain.com) and other services work correctly. After configuring DNS, the platform will be accessible at `https://learn.yourdomain.com` and Studio at `https://cms.learn.yourdomain.com`.

## Customization

You can customize the deployment by editing the script variables at the top:

- `NEW_USER`: The name of the admin user (default: `tutor`)
- `USER_PASSWORD`: The password for the admin user (default: `tutorpassword`)

## Troubleshooting

If you encounter issues during deployment:

- Check Docker status: `systemctl status docker`
- Review Tutor logs: `tutor local logs`
- Verify firewall configuration: `iptables -L -v`
- Check Docker data directory location: `docker info | grep "Docker Root Dir"`
- Verify IPv4 connectivity: `curl -4 ifconfig.co`

## Security Notes

- The script disables SSH password authentication by default, requiring key-based login
- The created admin user has passwordless sudo access for ease of administration
- A basic iptables firewall is configured to allow only necessary traffic

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## About ThreeFold

ThreeFold is a peer-to-peer internet infrastructure that aims to create a more sustainable, private, and secure internet. Learn more at [threefold.io](https://threefold.io).

## About OpenedX

Open edX is the open-source platform that powers edX courses and is used by many organizations to host their own instances of the platform. Learn more at [open.edx.org](https://open.edx.org/).