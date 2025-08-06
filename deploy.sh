#!/bin/bash

# EC2 Deployment Script for RabbitMQ Testing Application
set -e

echo "Starting deployment..."

# Detect OS and set package manager
if [ -f /etc/redhat-release ]; then
    # Amazon Linux / RHEL / CentOS
    PKG_MANAGER="yum"
    PYTHON_PKG="python3"
    PIP_PKG="python3-pip"
    
    # Update system packages
    sudo $PKG_MANAGER update -y
    
    # Install Python 3 and pip if not already installed
    sudo $PKG_MANAGER install -y $PYTHON_PKG $PIP_PKG python3-devel gcc
    
    # Install RabbitMQ if not already installed
    if ! command -v rabbitmq-server &> /dev/null; then
        echo "Installing RabbitMQ on Amazon Linux..."
        # Enable EPEL repository
        sudo $PKG_MANAGER install -y epel-release
        
        # Install Erlang (required for RabbitMQ)
        sudo $PKG_MANAGER install -y erlang
        
        # Install RabbitMQ
        wget https://github.com/rabbitmq/rabbitmq-server/releases/download/v3.12.10/rabbitmq-server-3.12.10-1.el8.noarch.rpm
        sudo $PKG_MANAGER install -y ./rabbitmq-server-3.12.10-1.el8.noarch.rpm
        rm -f rabbitmq-server-3.12.10-1.el8.noarch.rpm
    fi
    
elif [ -f /etc/debian_version ]; then
    # Ubuntu / Debian
    PKG_MANAGER="apt-get"
    PYTHON_PKG="python3"
    PIP_PKG="python3-pip"
    
    # Update system packages
    sudo $PKG_MANAGER update -y
    
    # Install Python 3 and pip if not already installed
    sudo $PKG_MANAGER install -y $PYTHON_PKG $PIP_PKG python3-venv python3-dev build-essential
    
    # Install RabbitMQ if not already installed
    if ! command -v rabbitmq-server &> /dev/null; then
        echo "Installing RabbitMQ on Ubuntu/Debian..."
        sudo $PKG_MANAGER install -y rabbitmq-server
    fi
else
    echo "Unsupported operating system"
    exit 1
fi

# Configure RabbitMQ
sudo systemctl enable rabbitmq-server
sudo systemctl start rabbitmq-server

# Wait for RabbitMQ to start
sleep 10

# Configure RabbitMQ management and users
sudo rabbitmq-plugins enable rabbitmq_management
sudo rabbitmqctl add_user admin admin123 || true
sudo rabbitmqctl set_user_tags admin administrator
sudo rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"

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
python3 -m venv venv || python3 -m pip install --user virtualenv && python3 -m virtualenv venv
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

# Start and enable RabbitMQ
echo "Starting RabbitMQ service..."
sudo systemctl start rabbitmq-server
sudo systemctl enable rabbitmq-server

# Wait for RabbitMQ to be ready
echo "Waiting for RabbitMQ to be ready..."
sleep 15

# Check RabbitMQ status
sudo systemctl status rabbitmq-server --no-pager || true

# Start and enable Celery worker
echo "Starting Celery worker..."
sudo systemctl start celery-worker
sudo systemctl enable celery-worker

# Check Celery worker status
sudo systemctl status celery-worker --no-pager || true

echo "Deployment completed successfully!"

# Test the deployment
echo "Testing deployment..."
cd $APP_DIR
source venv/bin/activate
python3 -c "from tasks import add; print('✓ Tasks module imported successfully')" || echo "⚠ Could not import tasks module"

# Display service status summary
echo ""
echo "=== Service Status Summary ==="
echo "RabbitMQ Status:"
sudo systemctl is-active rabbitmq-server || echo "RabbitMQ is not running"
echo "Celery Worker Status:"
sudo systemctl is-active celery-worker || echo "Celery Worker is not running"

# Display connection info
echo ""
echo "=== Connection Information ==="
if command -v curl &> /dev/null; then
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "Could not retrieve public IP")
    echo "RabbitMQ Management UI: http://$PUBLIC_IP:15672"
else
    echo "RabbitMQ Management UI: http://[YOUR-EC2-PUBLIC-IP]:15672"
fi
echo "Username: admin, Password: admin123"
echo ""
echo "Deployment log completed."
