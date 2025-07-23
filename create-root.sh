#!/bin/bash

echo "Starting GCP Root User Setup..."

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

#install nano
sudo apt install nano

# Get current username
current_user=$(who am i | awk '{print $1}')

# Add user to sudo group
echo -e "\n[1/5] Adding user to sudo group..."
usermod -aG sudo "$current_user"
echo "User $current_user added to sudo group"

# Set root password
echo -e "\n[2/5] Setting root password..."
while true; do
    passwd root
    if [ $? -eq 0 ]; then
        break
    else
        echo "Password setup failed, please try again"
    fi
done

# Configure hosts file
echo -e "\n[3/5] Configuring hosts file..."
instance_name=$(hostname)
echo "Current instance name: $instance_name"

# Backup current hosts file
cp /etc/hosts /etc/hosts.backup

# Add entry to hosts file
if ! grep -q "127.0.0.1 $instance_name" /etc/hosts; then
    echo "Adding entry to /etc/hosts..."
    echo "127.0.0.1 $instance_name" | tee -a /etc/hosts
else
    echo "Entry already exists in /etc/hosts"
fi

# Test root login
echo -e "\n[4/5] Testing root login..."
echo "Attempting to switch to root user..."
if su - root -c "echo 'Login as root successful!'"; then
    echo -e "\n[5/5] Root login test successful!"
else
    echo -e "\n[5/5] Root login failed! Please check your setup."
    exit 1
fi

echo -e "\n=== Setup Complete ==="
echo -e "\nAnda sekarang bisa login sebagai root dengan perintah:"
echo "  su - root"
echo "dan masukkan password yang baru saja Anda buat"
echo -e "\nUntuk keluar dari session root, gunakan perintah:"
echo "  exit"
