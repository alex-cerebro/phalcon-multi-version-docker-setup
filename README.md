# phalcon-multi-version-docker-setup

This repository contains the necessary scripts to set up a development environment with Phalcon in versions 3.4, 4, and 5 using Docker, Apache, and PHP. The provided setup script allows you to choose which versions of Phalcon you want to install and configures the environment automatically, making it easy to switch between different versions for development and testing purposes.

## Requirements

- Operating System: Ubuntu
- Docker
- Docker Compose
- Apache2
- PHP

## Installation Instructions

### Step 1: Clone the repository

```bash
git clone https://github.com/alex-cerebro/phalcon-multi-version-docker-setup.git
cd phalcon-multi-version-docker-setup
```
### Step 2: Assign execution permissions and run the installation script

```bash
chmod +x setup_phalcon_3.4-4-5.sh
./setup_phalcon_3.4-4-5.sh
```

###Step 3: Access the applications

Once the installation is complete, you can access the applications on the following ports:

- Phalcon 3.4: http://localhost:8081
- Phalcon 4: http://localhost:8082
- Phalcon 5: http://localhost:8083
  
###Notes
Ensure that ports 8081, 8082, and 8083 are free before running the script.
The script includes Xdebug configuration for local debugging.
For any issues or queries, please open an issue.
