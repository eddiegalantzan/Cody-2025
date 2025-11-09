#!/bin/bash
set -e

# Update system
apt-get update
apt-get install -y curl wget git build-essential

# Install PostgreSQL
apt-get install -y postgresql-${postgres_version}

# Configure PostgreSQL
sudo -u postgres psql -c "CREATE DATABASE ${database_name};" || true
sudo -u postgres psql -c "CREATE USER ${database_user} WITH PASSWORD '${db_password}';" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${database_name} TO ${database_user};"

# Configure PostgreSQL to listen on all interfaces (for remote access)
echo "listen_addresses = '*'" >> /etc/postgresql/${postgres_version}/main/postgresql.conf

# Configure pg_hba.conf to allow password authentication
echo "host    all             all             0.0.0.0/0               md5" >> /etc/postgresql/${postgres_version}/main/pg_hba.conf

# Restart PostgreSQL
systemctl restart postgresql
systemctl enable postgresql

# Install Node.js using NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_${node_version}.x | bash -
apt-get install -y nodejs

# Install Yarn
npm install -g yarn

# Install PM2 for process management
npm install -g pm2

# Create application directory
mkdir -p /opt/cody2025
chown -R root:root /opt/cody2025

# Configure firewall (UFW)
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow ${app_port}/tcp
ufw allow 5432/tcp
ufw --force enable

# Create systemd service template (to be configured when app is deployed)
# Note: Update User=root to a non-root user when deploying application
cat > /etc/systemd/system/cody2025.service <<EOF
[Unit]
Description=Cody-2025 Application
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/cody2025
Environment=NODE_ENV=staging
Environment=PORT=${app_port}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Note: Application code will be deployed separately
# Database is ready, Node.js is installed, firewall is configured
