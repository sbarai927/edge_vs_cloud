#!/bin/bash

set -e

APP_DIR="/home/ubuntu/hr-management"
VENV_DIR="$APP_DIR/venv"
GUNICORN_SOCKET="/home/ubuntu/gunicorn.sock"
GUNICORN_SERVICE="/etc/systemd/system/gunicorn.service"
NGINX_CONF="/etc/nginx/sites-available/hr-management"
NGINX_LINK="/etc/nginx/sites-enabled/hr-management"

echo "🔁 Updating and installing dependencies..."
sudo apt update -y
sudo apt install -y python3-pip python3-venv nginx git postgresql-client

echo "🧬 Cloning the repository..."
[ -d "$APP_DIR" ] || git clone https://github.com/ItsShahriar/HR-management.git "$APP_DIR"

echo "🐍 Setting up virtual environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

echo "📦 Installing Python dependencies..."
pip install --upgrade pip
pip install -r "$APP_DIR/requirements.txt"

echo "⚙️ Creating .env file..."
cat > "$APP_DIR/.env" <<EOF
DATABASE_URL=${db_url}
SECRET_KEY=${django_secret_key}
DEBUG=False
ALLOWED_HOSTS=*
EOF

echo "🔧 Setting up Gunicorn systemd service..."
cat > "$GUNICORN_SERVICE" <<EOF
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=$VENV_DIR/bin/gunicorn --workers 3 --bind unix:$GUNICORN_SOCKET --umask 007 orchid_hr.wsgi:application

[Install]
WantedBy=multi-user.target
EOF

echo "🌐 Setting up Nginx config..."
sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        root /home/ubuntu/project_static;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:$GUNICORN_SOCKET;
    }
}
EOF

echo "🛠️ Enabling Nginx site..."
sudo ln -sf "$NGINX_CONF" "$NGINX_LINK"
sudo nginx -t && sudo systemctl reload nginx

echo "📁 Collecting static files..."
cd "$APP_DIR"
python manage.py collectstatic --noinput

echo "📂 Applying database migrations..."
python manage.py migrate --noinput

echo "🚀 Enabling and starting Gunicorn..."
sudo systemctl daemon-reload
sudo systemctl enable gunicorn
sudo systemctl restart gunicorn

echo "✅ Deployment completed! Application is live."
