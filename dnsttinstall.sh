#!/bin/bash

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
    wget "https://github.com/Torch121/dnstt-server/releases/latest/download/$FILENAME"
    chmod +x "$FILENAME"
}

# Prompt for NS and listenAddr
prompt_for_details() {
    read -p "Enter NS (e.g., ns.example.com): " NS
    read -p "Enter listenAddr (e.g., 127.0.0.1:22): " LISTEN_ADDR
}

# Generate key files
generate_keys() {
    ./$FILENAME -gen-key -privkey-file server.key -pubkey-file server.pub
}

# Create systemd service file
create_systemd_service() {
    SERVICE_FILE="/etc/systemd/system/dnstt-server.service"
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
    sudo systemctl start dnstt-server
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

# Main script execution
main() {
    determine_architecture
    download_dnstt_server
    prompt_for_details
    generate_keys
    create_systemd_service
    start_systemd_service
    setup_iptables
    print_results
}

main
