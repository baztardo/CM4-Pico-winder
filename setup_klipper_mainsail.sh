#!/bin/bash
# Klipper + Mainsail Setup for CM4 CNC Winder
# Run this on your Raspberry Pi CM4

echo "Setting up Klipper + Mainsail for CNC Winder..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y git python3-numpy python3-matplotlib

# Install Klipper
echo "Installing Klipper..."
cd ~
git clone https://github.com/KevinOConnor/klipper.git
cd klipper
make menuconfig  # Configure for Linux process (just press enter)
make
sudo make install

# Install Mainsail (web interface)
echo "Installing Mainsail..."
cd ~
wget -q -O mainsail.zip https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip
sudo apt install -y unzip nginx
sudo unzip mainsail.zip -d /var/www/mainsail
sudo chown -R www-data:www-data /var/www/mainsail

# Configure Nginx
sudo tee /etc/nginx/sites-available/mainsail > /dev/null <<EOF
server {
    listen 80 default_server;
    server_name _;
    root /var/www/mainsail;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    location /websocket {
        proxy_pass http://127.0.0.1:7125/websocket;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/mainsail /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx

# Install Moonraker (API for Mainsail)
echo "Installing Moonraker..."
cd ~
git clone https://github.com/Arksine/moonraker.git
cd moonraker
./scripts/install-moonraker.sh

# Copy CNC winder config
echo "Setting up CNC winder config..."
cp ~/CM4-Pico-winder/cnc_winder_config.cfg ~/klipper_config.cfg

# Start services
sudo systemctl enable klipper
sudo systemctl enable moonraker
sudo systemctl start klipper
sudo systemctl start moonraker

echo ""
echo "🎉 Setup Complete!"
echo ""
echo "Web Interface: http://YOUR_CM4_IP"
echo "Config File: ~/klipper_config.cfg"
echo ""
echo "1. Flash Pico firmware: cp out/klipper.uf2 /media/YOUR_USER/RPI-RP2/"
echo "2. Connect Pico to CM4 USB"
echo "3. Open web interface on touchscreen"
echo "4. Use WIND_COIL macro to wind pickups!"

