#!/bin/bash

# Prompt for Container ID and Hostname
read -p "Enter Container ID (e.g., 100): " CT_ID
read -p "Enter Container Hostname: " HOSTNAME
read -p "Enter Container Password: " PASSWORD

# Safety check for IP
if [ "$CT_ID" -gt 254 ]; then
    echo "WARNING: Container ID $CT_ID exceeds 254."
    echo "This will result in an IP address of 10.0.0.${CT_ID} which may cause some issues..."
    read -p "Are you sure you want to proceed? (y/N): " CHECK
    if [[ "$CHECK" != "y" && "$CHECK" != "Y" ]]; then
        echo "Aborting operation."
        exit 1
    fi
fi

STORAGE="local-lvm"
TEMPLATE="local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
MEMORY=2048
SWAP=512
CORES=2

# Network Configuration
GATEWAY="10.0.0.1"
DNS_SERVER="1.1.1.1"
IP_ADDRESS="10.0.0.${CT_ID}/24"
NETWORK_BRIDGE="vnet0"

echo "--- Starting Auto-Provisioning for CT $CT_ID ---"
echo "--- Network: $IP_ADDRESS | GW: $GATEWAY | DNS: $DNS_SERVER ---"

pct create $CT_ID $TEMPLATE \
    --hostname $HOSTNAME \
    --password $PASSWORD \
    --storage $STORAGE \
    --ostype debian \
    --memory $MEMORY \
    --swap $SWAP \
    --cores $CORES \
    --net0 name=eth0,bridge=$NETWORK_BRIDGE,ip=$IP_ADDRESS,gw=$GATEWAY,type=veth \
    --nameserver $DNS_SERVER \
    --features nesting=1,keyctl=1 \
    --unprivileged 1

pct start $CT_ID

echo "--- Waiting 10s for boot and network... ---"
sleep 10

echo "--- Running apt update & upgrade... ---"
pct exec $CT_ID -- bash -c "apt-get update && apt-get upgrade -y"

echo "--- Installing git, btop, htop, wget, curl... ---"
pct exec $CT_ID -- bash -c "apt-get install -y git sudo btop htop wget curl"

echo "--- Installing Docker... ---"
pct exec $CT_ID -- bash -c "curl -fsSL https://get.docker.com | sh"

echo "--- Creating user docker-svc assigned to docker group... ---"
pct exec $CT_ID -- bash -c "useradd -m -s /bin/bash -G docker docker-svc"

echo "--- Setup Complete for $HOSTNAME ($CT_ID) ---"
echo "--- Access via: ssh root@${IP_ADDRESS%/*} ---"