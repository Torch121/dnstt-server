#!/bin/bash

SERVICE_FILE="/etc/systemd/system/dnstt-server.service"
FILENAME=""

# Define color codes for terminal text
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
    if [[ -f "$FILENAME" ]]; then
        echo "File $FILENAME already exists. Skipping download."
    else
        echo "Downloading $FILENAME..."
        wget -q "https://github.com/Torch121/dnstt-server/releases/latest/download/$FILENAME"
        chmod +x "$FILENAME"
    fi
}

# Prompt for NS and listenAddr with yellow text
prompt_for_details() {
    echo -e "${YELLOW}Enter NS (e.g., nn.achraf53.xyz):${NC}"
    read -p "" NS
    echo -e "${YELLOW}Enter listenAddr (e.g., 127.0.0.1:22):${NC}"
    read -p "" LISTEN_ADDR
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

# Print results in yellow text
print_results() {
    PUBKEY=$(cat server.pub)
    echo -e "${YELLOW}Installation complete.${NC}"
    echo -e "${YELLOW}Public Key:${NC} $PUBKEY"
    echo -e "${YELLOW}NS:${NC} $NS"
    echo -e "${YELLOW}Listen Address:${NC} $LISTEN_ADDR"
}

# Show current configuration information
show_info() {
    if [[ -f "server.pub" ]]; then
        PUBKEY=$(cat server.pub)
    else
        PUBKEY="No public key found."
    fi

    if [[ -f "$SERVICE_FILE" ]]; then
        CURRENT_EXEC_START=$(grep 'ExecStart' "$SERVICE_FILE")
        CURRENT_NS=$(echo "$CURRENT_EXEC_START" | sed -n 's/.* -privkey-file .* \([^ ]*\) .*/\1/p')
        CURRENT_LISTEN_ADDR=$(echo "$CURRENT_EXEC_START" | sed -n 's/.* -privkey-file .* [^ ]* \([^ ]*\)$/\1/p')
    else
        CURRENT_NS="No NS found."
        CURRENT_LISTEN_ADDR="No listen address found."
    fi

    echo -e "${YELLOW}Current Configuration:${NC}"
    echo -e "${YELLOW}Public Key:${NC} $PUBKEY"
    echo -e "${YELLOW}NS:${NC} $CURRENT_NS"
    echo -e "${YELLOW}Listen Address:${NC} $CURRENT_LISTEN_ADDR"
}

# Update NS and listenAddr
update_details() {
    # Extract current NS and listenAddr from service file
    if [[ -f "$SERVICE_FILE" ]]; then
        CURRENT_EXEC_START=$(grep 'ExecStart' "$SERVICE_FILE")
        CURRENT_NS=$(echo "$CURRENT_EXEC_START" | sed -n 's/.* -privkey-file .* \([^ ]*\) .*/\1/p')
        CURRENT_LISTEN_ADDR=$(echo "$CURRENT_EXEC_START" | sed -n 's/.* -privkey-file .* [^ ]* \([^ ]*\)$/\1/p')
        echo -e "${YELLOW}Current NS:${NC} $CURRENT_NS"
        echo -e "${YELLOW}Current Listen Address:${NC} $CURRENT_LISTEN_ADDR"
    else
        echo -e "${YELLOW}No existing service file found. Proceeding with new details.${NC}"
    fi

    echo -e "${YELLOW}Enter new NS (e.g., nn.achraf53.xyz):${NC}"
    read -p "" NS
    echo -e "${YELLOW}Enter new listenAddr (e.g., 127.0.0.1:22):${NC}"
    read -p "" LISTEN_ADDR
    create_or_update_systemd_service
    start_systemd_service
    echo -e "${YELLOW}Service updated and restarted.${NC}"
}

# Create user and set password (without enforcing password complexity)
create_user() {
    echo -e "${YELLOW}Enter username:${NC}"
    read -p "" USERNAME
    echo -e "${YELLOW}Enter password:${NC}"
    read -p "" PASSWORD
    echo
    echo "$USERNAME:$PASSWORD" | sudo chpasswd
    sudo usermod -aG sudo $USERNAME
    echo -e "${YELLOW}User $USERNAME created and added to sudo group.${NC}"
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
elif [[ "$1" == "--show-info" ]]; then
    show_info
else
    main
fi
