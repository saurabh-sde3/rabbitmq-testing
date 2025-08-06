# RabbitMQ Testing Application

A simple Celery-based application for testing RabbitMQ functionality with automated EC2 deployment.

## Project Structure

- `tasks.py` - Celery tasks definition
- `run_task.py` - Example script to run tasks
- `requirements.txt` - Python dependencies
- `deploy.sh` - EC2 deployment script
- `.github/workflows/deploy-to-ec2.yml` - GitHub Actions workflow

## Local Development

1. Install RabbitMQ:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install rabbitmq-server
   
   # macOS
   brew install rabbitmq
   
   # Windows
   # Download and install from https://www.rabbitmq.com/download.html
   ```

2. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Start RabbitMQ server:
   ```bash
   sudo systemctl start rabbitmq-server
   ```

4. Run Celery worker:
   ```bash
   celery -A tasks worker --loglevel=info
   ```

5. Run the test script:
   ```bash
   python run_task.py
   ```

## EC2 Deployment

### Prerequisites

1. **EC2 Instance**: Launch an Ubuntu 20.04+ EC2 instance
2. **Security Group**: Configure security group to allow:
   - SSH (port 22) from your IP
   - HTTP (port 80) if needed
   - Port 15672 for RabbitMQ management UI (optional)
   - Port 5672 for RabbitMQ (if accessing externally)

3. **GitHub Secrets**: Add the following secrets to your GitHub repository:
   - `AWS_ACCESS_KEY_ID` - Your AWS access key
   - `AWS_SECRET_ACCESS_KEY` - Your AWS secret key
   - `AWS_REGION` - AWS region (e.g., us-east-1)
   - `EC2_HOST` - Your EC2 instance public IP or hostname
   - `EC2_USER` - EC2 username (usually 'ubuntu' for Ubuntu instances)
   - `EC2_PRIVATE_KEY` - Your EC2 private key (.pem file content)

### Deployment Process

The GitHub Action will automatically:

1. **Build & Test**: Install dependencies and run basic tests
2. **Package**: Create a deployment package
3. **Deploy**: Copy files to EC2 and run deployment script
4. **Configure**: Set up RabbitMQ and Celery as systemd services
5. **Start**: Start all required services

### Manual Deployment

If you prefer to deploy manually:

1. Copy files to your EC2 instance:
   ```bash
   scp -i your-key.pem *.py requirements.txt deploy.sh ubuntu@your-ec2-ip:/home/ubuntu/
   ```

2. SSH into your EC2 instance:
   ```bash
   ssh -i your-key.pem ubuntu@your-ec2-ip
   ```

3. Run the deployment script:
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

### Post-Deployment

After successful deployment:

1. **RabbitMQ Management UI**: Access at `http://your-ec2-ip:15672`
   - Username: `admin`
   - Password: `admin123`

2. **Test the application**:
   ```bash
   cd /opt/rabbitmq-testing
   source venv/bin/activate
   python run_task.py
   ```

3. **Check service status**:
   ```bash
   sudo systemctl status rabbitmq-server
   sudo systemctl status celery-worker
   ```

4. **View logs**:
   ```bash
   sudo journalctl -u celery-worker -f
   tail -f /var/log/celery/worker.log
   ```

## Troubleshooting

### Common Issues

1. **Connection refused**: Ensure RabbitMQ is running and ports are open
2. **Permission denied**: Check file permissions and user ownership
3. **Service fails to start**: Check logs using `journalctl -u service-name`

### Useful Commands

```bash
# Restart services
sudo systemctl restart rabbitmq-server
sudo systemctl restart celery-worker

# Check RabbitMQ status
sudo rabbitmqctl status

# List RabbitMQ queues
sudo rabbitmqctl list_queues

# Monitor Celery workers
celery -A tasks inspect active
```

## Security Considerations

- Change default RabbitMQ credentials in production
- Use environment variables for sensitive configuration
- Implement proper firewall rules
- Use SSL/TLS for production deployments
- Consider using AWS IAM roles instead of access keys

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally
5. Submit a pull request
