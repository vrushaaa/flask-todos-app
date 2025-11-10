#!/bin/bash

set -e  # Exit on any error

APP_DIR="/var/www/todos-app"

echo "Installing system dependencies..."
sudo apt-get update -qq
sudo apt-get install -y python3 python3-pip python3-venv nginx

# Create app directory if it doesn't exist
if [ ! -d "$APP_DIR" ]; then
    echo "Creating app directory..."
    sudo mkdir -p "$APP_DIR"
fi

echo "Copying files..."
# Remove any existing venv in the source to avoid copying empty directory
sudo rm -rf /home/ubuntu/todos-deploy/venv
sudo cp -r /home/ubuntu/todos-deploy/* "$APP_DIR/"

cd "$APP_DIR"

# Always recreate virtual environment to ensure it's valid
echo "Creating virtual environment..."
sudo rm -rf "$APP_DIR/venv"
sudo python3 -m venv "$APP_DIR/venv"

echo "Installing Python packages..."
sudo "$APP_DIR/venv/bin/pip" install --upgrade pip -q
sudo "$APP_DIR/venv/bin/pip" install -r requirements.txt -q
sudo "$APP_DIR/venv/bin/pip" install gunicorn -q

# Configure Nginx
echo "Configuring Nginx..."
sudo bash -c 'cat > /etc/nginx/sites-available/todos-app <<EOF
server {
    listen 80;
    server_name _;

    location / {
        include proxy_params;
        proxy_pass http://unix:/var/www/todos-app/todos.sock;
    }
}
EOF'

sudo rm -f /etc/nginx/sites-enabled/default
sudo rm -f /etc/nginx/sites-enabled/todos-app
sudo ln -s /etc/nginx/sites-available/todos-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

# Set permissions
echo "Setting permissions..."
sudo chown -R www-data:www-data "$APP_DIR"
sudo chmod -R 755 "$APP_DIR"

# Stop old Gunicorn
echo "Stopping old Gunicorn..."
sudo pkill gunicorn || true
sleep 2

# Remove old socket
sudo rm -f "$APP_DIR/todos.sock"

# Start Gunicorn
echo "Starting Gunicorn..."
cd "$APP_DIR"
sudo -u www-data "$APP_DIR/venv/bin/gunicorn" \
    --workers 3 \
    --bind unix:"$APP_DIR/todos.sock" \
    --daemon \
    --access-logfile "$APP_DIR/access.log" \
    --error-logfile "$APP_DIR/error.log" \
    wsgi:app

# Wait a moment for it to start
sleep 3

# Check if it's running
if pgrep -f "gunicorn.*wsgi:app" > /dev/null; then
    echo "Deployment successful! 🎉"
    echo "App running at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'your-server-ip')"
else
    echo "Gunicorn failed to start!"
    echo "Check error log: sudo tail -50 $APP_DIR/error.log"
    exit 1
fi