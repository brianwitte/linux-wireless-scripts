#!/bin/bash

# Define some colors for output
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check for PCIe Wireless cards
echo -e "${GREEN}Checking for PCIe Wireless cards...${NC}"
echo -e "${YELLOW}"
lspci | grep -i wireless
echo -e "${NC}"

# Check for USB Wireless cards
echo -e "${GREEN}Checking for USB Wireless cards...${NC}"
echo -e "${YELLOW}"
lsusb | grep -i nic
echo -e "${NC}"

# Checking Network Configuration
echo -e "${GREEN}Checking network configuration...${NC}"

# List all network interfaces
echo -e "${YELLOW}"
ip link show
echo -e "${NC}"

# Checking for the wireless details of the currently active interfaces
for iface in $(ls /sys/class/net); do
    if iwconfig $iface 2>/dev/null | grep -q "ESSID"; then
        echo -e "${GREEN}Wireless details for interface ${iface}${NC}"
        echo -e "${YELLOW}"
        iwconfig $iface
        echo -e "${NC}"
    fi
done

