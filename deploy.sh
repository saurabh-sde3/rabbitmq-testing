#!/bin/bash

# EC2 Deployment Script for RabbitMQ Testing Application
set -e

echo "Starting deployment..."

# Update system packages
sudo apt-get update -y

# Install Python 3 and pip if not already installed
sudo apt-get install -y python3 python3-pip python3-venv

# Install RabbitMQ if not already installed
if ! command -v rabbitmq-server &> /dev/null; then
    echo "Installing RabbitMQ..."
    sudo apt-get install -y rabbitmq-server
    sudo systemctl enable rabbitmq-server
    sudo systemctl start rabbitmq-server
    
    # Configure RabbitMQ
    sudo rabbitmq-plugins enable rabbitmq_management
    sudo rabbitmqctl add_user admin admin123
    sudo rabbitmqctl set_user_tags admin administrator
    sudo rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"
fi

# Create application directory
APP_DIR="/opt/rabbitmq-testing"
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR

# Copy application files
cp *.py $APP_DIR/
cp requirements.txt $APP_DIR/

# Navigate to application directory
cd $APP_DIR

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install --upgrade pip
pip install -r requirements.txt

# Create systemd service for Celery worker
sudo tee /etc/systemd/system/celery-worker.service > /dev/null <<EOF
[Unit]
Description=Celery Worker Service
After=network.target rabbitmq-server.service
Requires=rabbitmq-server.service

[Service]
Type=forking
User=$USER
Group=$USER
EnvironmentFile=-/etc/default/celery
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/celery -A tasks worker --detach --loglevel=info --logfile=/var/log/celery/worker.log --pidfile=/var/run/celery/worker.pid
ExecStop=/bin/kill -s TERM \$MAINPID
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create Celery configuration
sudo mkdir -p /etc/default
sudo tee /etc/default/celery > /dev/null <<EOF
# Celery configuration
CELERY_BIN="$APP_DIR/venv/bin/celery"
CELERY_APP="tasks"
CELERYD_NODES="worker1"
CELERYD_OPTS="--time-limit=300 --concurrency=8"
CELERYD_LOG_FILE="/var/log/celery/%n%I.log"
CELERYD_PID_FILE="/var/run/celery/%n.pid"
CELERYD_USER="$USER"
CELERYD_GROUP="$USER"
CELERY_CREATE_DIRS=1
EOF

# Create log directories
sudo mkdir -p /var/log/celery
sudo mkdir -p /var/run/celery
sudo chown $USER:$USER /var/log/celery
sudo chown $USER:$USER /var/run/celery

# Reload systemd
sudo systemctl daemon-reload

# Start and enable services
sudo systemctl start rabbitmq-server
sudo systemctl enable rabbitmq-server

# Wait for RabbitMQ to be ready
sleep 10

sudo systemctl start celery-worker
sudo systemctl enable celery-worker

echo "Deployment completed successfully!"

# Test the deployment
echo "Testing deployment..."
cd $APP_DIR
source venv/bin/activate
python3 -c "from tasks import add; print('✓ Tasks module imported successfully')"

# Check service status
echo "Service status:"
sudo systemctl status rabbitmq-server --no-pager
sudo systemctl status celery-worker --no-pager

echo "RabbitMQ Management UI available at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):15672"
echo "Username: admin, Password: admin123"
