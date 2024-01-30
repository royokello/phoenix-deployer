# Phoenix Server Deploy Script

## Description

The `phoenix-server-deploy` script is a powerful automation tool designed to streamline the deployment process of web applications to an Ubuntu server. This Windows batch script efficiently packages and transfers important files and folders from your local environment to a remote Ubuntu server, ensuring a smooth and consistent deployment process.

## Features

- **Automated Zipping:** Compresses specified files and folders into a zip archive for efficient transfer.
- **Secure Transfer:** Utilizes `scp` for secure file transmission to the Ubuntu server.
- **Service Management:** Remotely stops the server service before deployment and restarts it after completion.
- **Server Clean-up:** Automatically deletes the existing application directory on the server and replaces it with the latest version.
- **Dependency Management:** Handles mix dependencies and database migrations on the server.
- **Easy to Use:** With SSH keys set up in the environment, the script offers a hassle-free deployment experience.

## Prerequisites

- Windows environment for running the batch script.
- `zip`, `scp`, and `ssh` installed on the local machine.
- SSH key-based authentication set up for the target Ubuntu server.
- Properly configured server service and application directory paths in the script.

## Usage

1. Edit the script to specify the source directory, destination directory, server user, server IP, and server service name.
2. Run the script by double-clicking `phoenix-server-deploy.bat` or executing it in the command prompt.
3. Monitor the output for successful completion or any error messages.

## Disclaimer

This script performs significant operations like file transfer and directory deletion. It is highly recommended to test it in a non-production environment and ensure you have backups of critical data before use.

