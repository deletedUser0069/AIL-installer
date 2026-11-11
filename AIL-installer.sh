#!/bin/bash
# Stop script immediately on any error
set -e

echo "========================================================="
echo "   AIL FRAMEWORK: ULTIMATE 1-CLICK INSTALLER             "
echo "========================================================="

# Save our starting directory securely
BASE_DIR="$PWD"
AIL_DIR="$BASE_DIR/ail-framework"

echo -e "\n[*] STEP 1: Installing System Dependencies & Tor..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y tor libmagic1 ghostscript exiftool qpdf python3-venv python3-pip git curl

echo -e "\n[*] STEP 2: Configuring Tor Proxy Tunnel..."
# Safely append the proxy routing (added sudo to grep to bypass permission blocks)
sudo grep -qxF 'SocksPort 127.0.0.1:9050' /etc/tor/torrc || echo 'SocksPort 127.0.0.1:9050' | sudo tee -a /etc/tor/torrc > /dev/null
sudo systemctl restart tor
sudo systemctl enable tor

echo -e "\n[*] STEP 3: Deploying AIL Framework"
cd "$BASE_DIR"
git clone --recursive https://github.com/ail-project/ail-framework.git
cd "$AIL_DIR"
sleep 10
# Enforce executable permissions just in case git clone dropped them
./installing_deps.sh

sudo sed -i 's/^host = 127\.0\.0\.1/host = 0.0.0.0/' "$AIL_DIR/configs/core.cfg"

echo -e "\n[*] STEP 4: Configuring SMTP (Notifications)......"

CONFIG_FILE="$AIL_DIR/configs/core.cfg"

# Ask user for values
read -p "Enter sender email: " SENDER
read -s -p "Enter sender password: " SENDER_PW
echo ""
read -p "Enter SMTP host (e.g. smtp.gmail.com): " SENDER_HOST
read -p "Enter SMTP port [default: 587]: " SENDER_PORT

# Default port fallback
SENDER_PORT=${SENDER_PORT:-587}

# sender_user automatically equals sender
SENDER_USER="$SENDER"

echo "[*] Updating configuration..."

# Replace values inside [Notifications] section only
sudo sed -i "/^\[Notifications\]/,/^\[/ s|^sender *=.*|sender = $SENDER|" "$CONFIG_FILE"
sudo sed -i "/^\[Notifications\]/,/^\[/ s|^sender_user *=.*|sender_user = $SENDER_USER|" "$CONFIG_FILE"
sudo sed -i "/^\[Notifications\]/,/^\[/ s|^sender_pw *=.*|sender_pw = $SENDER_PW|" "$CONFIG_FILE"
sudo sed -i "/^\[Notifications\]/,/^\[/ s|^sender_host *=.*|sender_host = $SENDER_HOST|" "$CONFIG_FILE"
sudo sed -i "/^\[Notifications\]/,/^\[/ s|^sender_port *=.*|sender_port = $SENDER_PORT|" "$CONFIG_FILE"

echo "[+] SMTP configuration updated."

echo -e "\n[*] STEP 5: Deploying Lacus Dark Web Crawler (Docker)..."
cd "$BASE_DIR"
git clone https://github.com/ail-project/lacus.git
cd lacus

# Safely override Docker Compose settings without breaking YAML formatting
cat <<EOF > docker-compose.override.yml
services:
  lacus:
    network_mode: "host"
EOF

sudo docker compose up --build -d

echo -e "\n[*] STEP 6: Setting up Telegram Feeder Environment..."
cd "$BASE_DIR"
git clone https://github.com/ail-project/ail-feeder-telegram.git
cd ail-feeder-telegram

python3 -m venv venv
source venv/bin/activate
# Upgrade pip inside the sandbox to prevent installation errors
python3 -m pip install --upgrade pip
pip3 install -U -r requirements.txt
cp etc/conf.cfg.sample etc/conf.cfg
deactivate

# Automatically detect the server's public IP to avoid Docker networking loops
SERVER_IP=$(curl -4 -s ifconfig.me || ip -4 route get 1.1.1.1 | awk '{print $7; exit}')
#Email & Password to login
cat "$AIL_DIR/DEFAULT_PASSWORD"

#Run AIL-Framework
"$AIL_DIR/bin/LAUNCH.sh" -l

echo -e "\n========================================================="
echo " [+] INSTALLATION COMPLETE!                              "
echo "========================================================="
echo " Next Steps:"
echo " 1. Access AIL Dashboard: https://$SERVER_IP:7000"
echo "    Your AIL Login Credentials are:"
echo "    Email:    $(grep '^email=' "$AIL_DIR/DEFAULT_PASSWORD" | cut -d '=' -f2)"
echo "    Password: $(grep '^password=' "$AIL_DIR/DEFAULT_PASSWORD" | cut -d '=' -f2)"
echo "    API Key:  $(grep '^API_Key=' "$AIL_DIR/DEFAULT_PASSWORD" | cut -d '=' -f2)"
echo ""
echo " 2. Add Lacus Crawler URL: http://127.0.0.1:7100"
echo " 3. Edit Telegram Config: nano ail-feeder-telegram/etc/conf.cfg"
