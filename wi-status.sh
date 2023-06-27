#!/bin/bash

# NOTE
# loaded modules will search for rtw drivers by default
# unless argument is passed to wi-status.sh
#
#   E.g. ./wi-status.sh rtl
#

# Define some colors  output
WHITE='\e[0;37m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Set default module search pattern
module_search_pattern=${1:-rtw}

# Check for PCIe Wireless cards
echo -e "${GREEN}Checking for PCIe Wireless cards...${NC}"
echo -e "${WHITE}"
lspci | grep -i wireless
echo -e "${NC}"

# Check for USB Wireless cards
echo -e "${GREEN}Checking for USB Wireless cards...${NC}"
echo -e "${WHITE}"
lsusb | grep 'NIC'
echo -e "${NC}"

# Checking Network Configuration
echo -e "${GREEN}Checking network configuration...${NC}"

# List all network interfaces
echo -e "${WHITE}"
ip link show
echo -e "${NC}"

# Checking for the wireless details of the currently active interfaces
for iface in $(ls /sys/class/net); do
    if iwconfig $iface 2>/dev/null | grep -q "ESSID"; then
        echo -e "${GREEN}Wireless details for interface ${iface}${NC}"
        echo -e "${WHITE}"
        iwconfig $iface
        echo -e "${NC}"
    fi
done

# Checking for the currently loaded kernel version
echo -e "${GREEN}Checking for currently loaded kernel version...${NC}"
echo -e "${WHITE}"
uname -r
echo -e "${NC}"

# List all loaded modules based on argument or default 'rtw'
echo -e "${GREEN}Checking for loaded modules matching '${module_search_pattern}'...${NC}"
echo -e "${WHITE}"
lsmod | grep "${module_search_pattern}"
echo -e "${NC}"
