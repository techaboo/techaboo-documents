#!/bin/bash

# Exit on error
set -e

# Update and upgrade
echo "Updating and upgrading packages..."
sudo apt update && sudo apt full-upgrade -y

# Install general purpose packages for a server
echo "Installing general purpose packages..."
sudo apt install -y \
    curl wget gpg coreutils apt-transport-https \
    ca-certificates software-properties-common \
    lsb-release dirmngr python3 tmux neovim git plocate

# Clean up the cache
echo "Cleaning up package cache..."
sudo apt clean && sudo apt autoremove -y

# Install Ubuntu Advantage Tools
echo "Installing Ubuntu Advantage Tools..."
sudo apt install -y ubuntu-advantage-tools
echo "Attaching Pro license..."
sudo pro attach || echo "Pro license already attached or could not attach."

# Install and configure unattended upgrades
echo "Installing unattended-upgrades..."
sudo apt install -y unattended-upgrades
echo "Configuring unattended-upgrades..."
sudo bash -c 'cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
    "${distro_id}:${distro_codename}-updates";
};
EOF'

# Configure auto upgrade intervals
echo "Configuring auto-upgrades..."
sudo bash -c 'cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF'

# Set timezone
echo "Setting timezone to America/New_York..."
sudo timedatectl set-timezone America/New_York

# Install Cockpit web console
echo "Installing Cockpit web console..."
. /etc/os-release
sudo apt install -t "${VERSION_CODENAME}-backports" cockpit -y

# Configure Cockpit network settings
echo "Configuring Cockpit network settings..."
sudo bash -c 'cat >> /etc/NetworkManager/conf.d/10-globally-managed-devices.conf << EOF
[keyfile]
unmanaged-devices=none
EOF'
# Set Cockpit password for a user
echo "Setting Cockpit password..."
COCKPIT_USER="azcdxprod"  # Replace with the desired username
COCKPIT_PASSWORD="osavo105115!"  # Replace with the desired password

# Check if user exists; if not, create it
if id "$COCKPIT_USER" &>/dev/null; then
    echo "User '$COCKPIT_USER' exists. Setting password..."
else
    echo "User '$COCKPIT_USER' does not exist. Creating user..."
    sudo useradd -m -s /bin/bash "$COCKPIT_USER"
fi

# Set the password for the user
echo "$COCKPIT_USER:$COCKPIT_PASSWORD" | sudo chpasswd

# Ensure the user has administrative privileges (optional)
echo "Adding '$COCKPIT_USER' to sudo group..."
sudo usermod -aG sudo "$COCKPIT_USER"

echo "Cockpit password for user '$COCKPIT_USER' has been set."
# Add a dummy network connection
echo "Adding a dummy network connection..."
sudo nmcli con add type dummy con-name fake ifname fake0 ip4 1.2.3.4/24 gw4 1.2.3.1

# Modify the systemd-networkd service
echo "Modifying systemd-networkd service..."
sudo mkdir -p /etc/systemd/system/systemd-networkd-wait-online.service.d
sudo bash -c 'cat > /etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/lib/systemd/systemd-networkd-wait-online --interface=eth0
EOF'

# Restart the service
echo "Restarting systemd-networkd-wait-online service..."
sudo systemctl restart systemd-networkd-wait-online.service

# Change SSH port
echo "Changing SSH port to 2302..."
sudo sed -i 's/^#Port 22/Port 2302/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Configure UFW
echo "Configuring UFW..."
sudo ufw allow 53
sudo ufw allow 88
sudo ufw allow 445
sudo ufw allow 636
sudo ufw limit 2302
sudo ufw limit 2308
sudo ufw limit 2812
sudo ufw allow 80/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 443
sudo ufw allow 8443
sudo ufw allow 9090/tcp
sudo ufw enable

# Install auditd
echo "Installing auditd..."
sudo apt install -y auditd audispd-plugins
sudo systemctl enable auditd
sudo systemctl start auditd

# Configure auditd rules
echo "Configuring auditd rules..."
sudo bash -c 'cat > /etc/audit/rules.d/audit.rules << EOF
# Linux Audit Daemon - Best Practice Configuration
# /etc/audit/audit.rules

# Remove any existing rules
-D

# Buffer Size
-b 10240

# Failure Mode
-f 1

# Ignore errors
-i
EOF'

# Reload and restart auditd
echo "Reloading and restarting auditd..."
sudo systemctl daemon-reload
sudo systemctl restart auditd

# Install Monit
echo "Installing Monit..."
sudo apt install -y monit
sudo systemctl enable monit
sudo systemctl start monit

# Configure Monit
echo "Configuring Monit..."
sudo bash -c 'cat > /etc/monit/monitrc << EOF
set httpd port 2812 and
    use address localhost
    allow localhost
    allow azcdxprod:osavo105115

check process postgresql with pidfile /var/run/postgresql/postmaster.pid
    start program = "/usr/lib/postgresql/15/bin/postgres -D /var/lib/postgresql/15/main"
    stop program = "/usr/lib/postgresql/15/bin/pg_ctl -D /var/lib/postgresql/15/main -m fast"
    if 3 restarts within 5 cycles then alert

check process tomcat with pidfile /opt/tomcat/current/temp/tomcat.pid
    start program = "/opt/tomcat/current/bin/startup.sh"
    stop program = "/opt/tomcat/current/bin/shutdown.sh"
    if cpu > 60% for 2 cycles then alert
    if cpu > 80% for 5 cycles then restart
    if totalmem > 200.0 MB for 5 cycles then restart
    if children > 250 then restart
    if disk read > 1000 kb/s for 10 cycles then alert
    if disk write > 1000 kb/s for 10 cycles then alert
    if failed port 8443 protocol https with timeout 60 seconds then restart
    if 3 restarts within 5 cycles then alert
EOF'

# Check the config file for errors
echo "Checking Monit config for errors..."
sudo monit -t

# Reload Monit
echo "Reloading Monit..."
sudo systemctl daemon-reload
sudo monit reload

echo "Installing Microsoft Defender for Endpoint..."

# Set Ubuntu version for repository setup (replace VERSION as needed)
VERSION="24.04"  # Change to 22.04 if using that version

# Add the Microsoft repository
echo "Adding Microsoft repository..."
curl -o microsoft.list https://packages.microsoft.com/config/ubuntu/${VERSION}/prod.list
sudo mv ./microsoft.list /etc/apt/sources.list.d/microsoft-prod.list
curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/microsoft-prod.gpg > /dev/null

# Install prerequisites
echo "Installing prerequisites..."
sudo apt-get install -y apt-transport-https

# Update and upgrade packages
echo "Updating and upgrading packages..."
sudo apt-get update && sudo apt-get upgrade -y

# Install Microsoft Defender for Endpoint
echo "Installing Microsoft Defender for Endpoint..."
sudo apt install -y mdatp libplist-utils
# Replace {{version}} with the correct version (22.10 or 24.04)
curl -o microsoft.list https://packages.microsoft.com/config/ubuntu/{{version}}/prod.list
sudo mv ./microsoft.list /etc/apt/sources.list.d/microsoft-prod.list
curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/microsoft-prod.gpg > /dev/null
sudo apt install -y apt-transport-https

# Run another update and upgrade
echo "Running another update and upgrade..."
sudo apt update && sudo apt upgrade -y

# Configure Microsoft Defender for Endpoint
echo "Configuring Microsoft Defender for Endpoint..."
sudo mdatp config passive-mode --value disabled
sudo mdatp config real-time-protection --value enabled
sudo mdatp config behavior-monitoring --value enabled
sudo mdatp config cloud --value enabled
sudo mdatp config cloud-diagnostic --value enabled
sudo mdatp threat policy set --type potentially_unwanted_application --action block
# Replace {{major_version}} with the major version (22 or 24)
sudo mdatp edr tag set --name GROUP --value Ubuntu{{major_version}}
sudo systemctl restart mdatp

# Verify health of MDATP and run initial update and scan
echo "Verifying health of Microsoft Defender..."
sudo mdatp health
sudo mdatp definitions update
sudo mdatp scan quick

# Reboot the system
echo "Rebooting the system..."
sudo reboot
