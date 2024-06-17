#!/bin/bash

SERVICE_FILE="/etc/systemd/system/dnstt-server.service"
FILENAME=""

# Function to determine architecture
determine_architecture() {
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        echo "64-bit architecture detected."
        FILENAME="dnstt-server-64"
    elif [[ "$ARCH" == "i386" || "$ARCH" == "i686" ]]; then
        echo "32-bit architecture detected."
        FILENAME="dnstt-server-386"
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi
}

# Function to download the appropriate dnstt-server file
download_dnstt_server() {
    echo "Downloading $FILENAME..."
    wget -q "https://github.com/Torch121/dnstt-server/releases/latest/download/$FILENAME"
    chmod +x "$FILENAME"
}

# Prompt for NS and listenAddr
prompt_for_details() {
    read -p "Enter NS (e.g., nn.achraf53.xyz): " NS
    read -p "Enter listenAddr (e.g., 127.0.0.1:22): " LISTEN_ADDR
}

# Generate key files
generate_keys() {
    ./$FILENAME -gen-key -privkey-file server.key -pubkey-file server.pub
}

# Create or update systemd service file
create_or_update_systemd_service() {
    echo "[Unit]
Description=DNSTT Server
After=network.target

[Service]
ExecStart=$(pwd)/$FILENAME -udp :5300 -privkey-file $(pwd)/server.key $NS $LISTEN_ADDR
WorkingDirectory=$(pwd)
Restart=always

[Install]
WantedBy=multi-user.target" | sudo tee $SERVICE_FILE
}

# Start and enable the systemd service
start_systemd_service() {
    sudo systemctl daemon-reload
    sudo systemctl enable dnstt-server
    sudo systemctl restart dnstt-server
}

# Set up iptables rules
setup_iptables() {
    sudo iptables -I INPUT -p udp --dport 5300 -j ACCEPT
    sudo iptables -t nat -I PREROUTING -i eth0 -p udp --dport 53 -j REDIRECT --to-ports 5300
    sudo ip6tables -I INPUT -p udp --dport 5300 -j ACCEPT
    sudo ip6tables -t nat -I PREROUTING -i eth0 -p udp --dport 53 -j REDIRECT --to-ports 5300
}

# Print results
print_results() {
    PUBKEY=$(cat server.pub)
    echo "Installation complete."
    echo "Public Key: $PUBKEY"
    echo "NS: $NS"
    echo "Listen Address: $LISTEN_ADDR"
}

# Update NS and listenAddr
update_details() {
    read -p "Enter new NS (e.g., nn.achraf53.xyz): " NS
    read -p "Enter new listenAddr (e.g., 127.0.0.1:22): " LISTEN_ADDR
    create_or_update_systemd_service
    start_systemd_service
    echo "Service updated and restarted."
}

# Create user and set password
create_user() {
    read -p "Enter username: " USERNAME
    read -sp "Enter password: " PASSWORD
    echo
    sudo useradd -m -s /bin/bash $USERNAME
    echo "$USERNAME:$PASSWORD" | sudo chpasswd
    sudo usermod -aG sudo $USERNAME
    echo "User $USERNAME created and added to sudo group."
}

# Main script execution
main() {
    determine_architecture
    download_dnstt_server
    prompt_for_details
    generate_keys
    create_or_update_systemd_service
    start_systemd_service
    setup_iptables
    print_results
}

# Check for update or user creation flag
if [[ "$1" == "--update" ]]; then
    determine_architecture
    update_details
elif [[ "$1" == "--create-user" ]]; then
    create_user
else
    main
fi
