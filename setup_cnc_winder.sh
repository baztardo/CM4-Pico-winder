#!/bin/bash
# CNC Winder Setup for CM4 Touchscreen Control System
# Based on Klipper firmware architecture and Mainsail web interface
# Run this on your Raspberry Pi CM4

echo "Setting up CNC Winder Control System..."
echo "Based on Klipper firmware and Mainsail web interface concepts"
echo "Special thanks to the Klipper and Mainsail communities!"

# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y git python3-numpy python3-matplotlib chromium-browser

# Install Klipper (firmware host)
echo "Installing Klipper firmware host..."
cd ~
git clone https://github.com/KevinOConnor/klipper.git
cd klipper
make menuconfig  # Configure for Linux process (just press enter)
make
sudo make install

# Install CNC Winder Web Interface (based on Mainsail)
echo "Installing CNC Winder Web Interface..."
cd ~
wget -q -O cnc_interface.zip https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip
sudo apt install -y unzip nginx
sudo unzip cnc_interface.zip -d /var/www/cnc-winder
sudo chown -R www-data:www-data /var/www/cnc-winder

# Configure touchscreen auto-start
sudo tee /home/pi/.xsession > /dev/null <<EOF
#!/bin/sh
xset -dpms
xset s off
chromium-browser --kiosk --app=http://localhost --no-first-run --disable-infobars --disable-session-crashed-bubble --disable-component-update --user-agent="CNC-Winder/1.0"
EOF
sudo chmod +x /home/pi/.xsession

# Configure Nginx for CNC Winder interface
sudo tee /etc/nginx/sites-available/cnc-winder > /dev/null <<EOF
server {
    listen 80 default_server;
    server_name _;
    root /var/www/cnc-winder;
    index index.html;

    # Add custom headers
    add_header X-Powered-By "CNC Winder Control System" always;
    add_header X-Source "Based on Klipper/Mainsail architecture" always;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /websocket {
        proxy_pass http://127.0.0.1:7125/websocket;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/cnc-winder /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx

# Install Moonraker (API for web interface)
echo "Installing Moonraker API service..."
echo "Moonraker provides the API layer for the web interface"
cd ~
git clone https://github.com/Arksine/moonraker.git
cd moonraker
./scripts/install-moonraker.sh

# Copy CNC winder config
echo "Setting up CNC winder configuration..."
cp ~/CM4-Pico-winder/config/cnc_winder_config.cfg ~/klipper_config.cfg

# Configure touchscreen (if present)
if [ -e "/dev/fb0" ] || [ -e "/dev/fb1" ]; then
    echo "Touchscreen detected - configuring auto-start..."
    sudo apt install -y xserver-xorg xinit openbox lightdm
    sudo tee /usr/share/X11/xorg.conf.d/99-fbturbo.conf > /dev/null <<EOF
Section "Device"
    Identifier "Allwinner A10/A13 FBDEV"
    Driver "fbturbo"
    Option "fbdev" "/dev/fb0"
    Option "SwapbuffersWait" "true"
EndSection
EOF
    sudo systemctl enable lightdm
    sudo systemctl set-default graphical.target
else
    echo "No touchscreen detected - web interface available at http://YOUR_CM4_IP"
fi

# Start services
sudo systemctl enable klipper
sudo systemctl enable moonraker
sudo systemctl start klipper
sudo systemctl start moonraker

echo ""
echo "🎉 CNC Winder Setup Complete!"
echo ""
echo "Web Interface: http://YOUR_CM4_IP"
echo "Config File: ~/klipper_config.cfg"
echo ""
echo "📝 CREDITS:"
echo "  - Based on Klipper firmware architecture"
echo "  - Web interface inspired by Mainsail"
echo "  - Special thanks to Kevin O'Connor and the Klipper community"
echo "  - Thanks to the Mainsail team for the excellent web interface"
echo ""
echo "🚀 NEXT STEPS:"
echo "1. Flash Pico firmware: cp out/klipper.uf2 /media/YOUR_USER/RPI-RP2/"
echo "2. Connect Pico to CM4 USB"
echo "3. Open web interface on touchscreen"
echo "4. Use WIND_COIL macro to wind pickups!"
echo ""
echo "💡 SUPPORT THE PROJECTS:"
echo "   Klipper: https://github.com/KevinOConnor/klipper"
echo "   Mainsail: https://github.com/mainsail-crew/mainsail"

