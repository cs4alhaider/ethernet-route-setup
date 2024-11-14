#!/bin/bash

# ethernet_route_setup.sh - A script to add routes and update /etc/hosts for specified domains or IP addresses,
# with an option to auto-detect the active Ethernet interface or use a specified MAC address.

# Color codes
RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Exit immediately if a command exits with a non-zero status
set -e

# ==============================
# 1. Dependency Checks
# ==============================

function check_dependencies() {
  local dependencies=("dig" "route" "grep" "awk" "sudo" "osascript" "ifconfig" "networksetup")
  local missing_dependencies=()

  for cmd in "${dependencies[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
      missing_dependencies+=("$cmd")
    fi
  done

  if [ ${#missing_dependencies[@]} -ne 0 ]; then
    echo -e "${RED}❌ Missing dependencies: ${missing_dependencies[*]}${NC}"
    echo -e "${YELLOW}Please install the missing dependencies and try again.${NC}"
    exit 1
  fi
}

# ==============================
# 2. User-Friendly Output with Colors and ASCII Art
# ==============================

echo -e "${ORANGE}=========================================================="
echo -e "                Ethernet Route Setup Script"
echo -e "--------------------------------------------------------"
echo -e "Starting a script written by Abdullah Alhaider"
echo -e "Version: 1.0.0"
echo -e "--------------------------------------------------------"
echo -e "Please visit:"
echo -e "https://github.com/cs4alhaider/ethernet-route-setup"
echo -e "for more information, documentation and updates."
echo -e "--------------------------------------------------------"
echo -e "This script helps configure network routes and hosts"
echo -e "for specified domains or IP addresses using Ethernet interfaces."
echo -e "==========================================================${NC}"

# ==============================
# 3. Command-Line Help and Usage Information
# ==============================

function display_help() {
  echo -e "${BLUE}Usage: $0 [options]${NC}"
  echo
  echo "Options:"
  echo "  --config-dir DIR      Specify a custom configuration directory."
  echo "  --auto-detect         Auto-detect the active Ethernet interface instead of using a MAC address."
  echo "  --dry-run             Run the script without making any changes."
  echo "  -h, --help            Display this help message."
  exit 0
}

# ==============================
# 4. Variables and Configuration
# ==============================

# Default configuration directory
CONFIG_DIR="./config"
AUTO_DETECT=false

# Parse command-line arguments
DRY_RUN=false

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --config-dir)
      CONFIG_DIR="$2"
      shift
      ;;
    --auto-detect)
      AUTO_DETECT=true
      ;;
    --dry-run)
      DRY_RUN=true
      echo -e "${YELLOW}Running in dry run mode...${NC}"
      ;;
    -h|--help)
      display_help
      ;;
    *)
      echo -e "${RED}Unknown parameter passed: $1${NC}"
      display_help
      ;;
  esac
  shift
done

# Load MAC address and domains from configuration files
MAC_ADDRESS_FILE="$CONFIG_DIR/mac_address.conf"
DOMAINS_FILE="$CONFIG_DIR/domains.conf"

if [ ! -f "$MAC_ADDRESS_FILE" ]; then
  echo -e "${RED}❌ MAC address file not found: $MAC_ADDRESS_FILE${NC}"
  exit 1
fi

if [ ! -f "$DOMAINS_FILE" ]; then
  echo -e "${RED}❌ Domains file not found: $DOMAINS_FILE${NC}"
  exit 1
fi

MAC_ADDRESS=$(cat "$MAC_ADDRESS_FILE" | xargs)
mapfile -t domains < "$DOMAINS_FILE" 2>/dev/null || domains=($(grep . "$DOMAINS_FILE"))

echo -e "${GREEN}✅ Loaded MAC address:${NC}"
echo -e "${GREEN}   • $MAC_ADDRESS\n${NC}"
echo -e "${GREEN}✅ Loaded domains or IP addresses:${NC}"
for i in "${!domains[@]}"; do
  echo -e "${GREEN}   $((i+1)). ${domains[$i]}${NC}"
done
echo

# ==============================
# 5. Sudo Credential Caching
# ==============================

# Prompt for sudo password upfront
sudo -v

# Keep the sudo timestamp updated while the script runs
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

# ==============================
# 6. Idempotency Functions
# ==============================

function route_exists() {
  local ip="$1"
  if netstat -rn | grep -q "$ip"; then
    return 0
  else
    return 1
  fi
}

function hosts_entry_exists() {
  local entry="$1"
  if grep -q "$entry" /etc/hosts; then
    return 0
  else
    return 1
  fi
}

# ==============================
# 7. Function to Get Active Ethernet Interface
# ==============================

function get_active_ethernet_interface() {
  # Get all Ethernet interfaces
  ethernet_interfaces=($(networksetup -listallhardwareports | awk '/Hardware Port: Ethernet/{getline; print $2}'))

  active_interfaces=()
  # Check each Ethernet interface to see if it's active
  for interface in "${ethernet_interfaces[@]}"; do
    if ifconfig "$interface" | grep -q "status: active"; then
      active_interfaces+=("$interface")
    fi
  done

  if [ ${#active_interfaces[@]} -eq 1 ]; then
    echo "${active_interfaces[0]}"
  elif [ ${#active_interfaces[@]} -gt 1 ]; then
    echo -e "${YELLOW}⚠️  Multiple active Ethernet interfaces found.${NC}"
    # Use the first active interface (modify this if you want to select a specific one)
    echo "${active_interfaces[0]}"
  else
    # No active Ethernet interfaces
    echo ""
  fi
}

# ==============================
# 8. Start Time for Performance Measurement
# ==============================

start_time=$(date +%s)

# ==============================
# 9. Main Script Execution
# ==============================

# Check dependencies
check_dependencies

echo -e "${BLUE}Starting the route addition script...${NC}"

# Determine whether to auto-detect the Ethernet interface or use MAC address
if [ "$AUTO_DETECT" = true ]; then
  ETHERNET_INTERFACE=$(get_active_ethernet_interface)

  if [ -z "$ETHERNET_INTERFACE" ]; then
    echo -e "${RED}❌ No active Ethernet interface found. Exiting.${NC}"
    exit 1
  else
    echo -e "${GREEN}✅ Active Ethernet interface detected: $ETHERNET_INTERFACE${NC}"
  fi
fi

# Loop through each entry in domains.conf
for entry in "${domains[@]}"; do
  echo -e "${BLUE}🌐 Processing entry: $entry${NC}"

  # Remove any port from the entry, if present
  IP="${entry%%:*}"  # Extracts IP by removing anything after a colon

  # Check if the entry is an IP address
  if [[ $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${GREEN}✅ Detected IP address: $IP${NC}"
  else
    # Entry is a domain name; perform DNS lookup
    IP=$(dig +short "$entry" | grep -E '^[0-9.]+$' | head -n 1)
    if [ -z "$IP" ]; then
      echo -e "${RED}❌ Failed to retrieve IP for $entry. Skipping...${NC}"
      continue
    else
      echo -e "${GREEN}✅ Retrieved IP for $entry: $IP${NC}"
    fi

    # Only add domain names to /etc/hosts
    if ! hosts_entry_exists "$entry"; then
      echo -e "${BLUE}📝 $entry not found in /etc/hosts. Proceeding to add...${NC}"
      if [ "$DRY_RUN" = false ]; then
        echo "$IP $entry" | sudo tee -a /etc/hosts > /dev/null
        echo -e "${GREEN}✅ Added $entry with IP $IP to /etc/hosts${NC}"
      else
        echo -e "${YELLOW}DRY RUN: Would add $entry with IP $IP to /etc/hosts${NC}"
      fi
    else
      echo -e "${YELLOW}⚠️  $entry is already in /etc/hosts. Skipping hosts file update...${NC}"
    fi
  fi

  # Determine route addition method based on the --auto-detect flag
  if route_exists "$IP"; then
    echo -e "${YELLOW}⚠️  Route for $IP already exists. Skipping route addition...${NC}"
  else
    if [ "$AUTO_DETECT" = true ]; then
      # Add the route via the active Ethernet interface
      if [ "$DRY_RUN" = false ]; then
        sudo route -n add -host "$IP" -interface "$ETHERNET_INTERFACE"
        echo -e "${GREEN}✅ Route added for $entry ($IP) via interface $ETHERNET_INTERFACE${NC}"
      else
        echo -e "${YELLOW}DRY RUN: Would add route for $entry ($IP) via interface $ETHERNET_INTERFACE${NC}"
      fi
    else
      # Add the route via MAC address
      GATEWAY=$(route -n get "$IP" 2>/dev/null | awk '/gateway:/ {print $2}')
      if [ -z "$GATEWAY" ]; then
        echo -e "${RED}❌ Failed to retrieve gateway for IP $IP of $entry. Skipping route addition...${NC}"
        continue
      fi
      if [ "$DRY_RUN" = false ]; then
        sudo route add -host "$IP" "$GATEWAY" -link "$MAC_ADDRESS"
        echo -e "${GREEN}✅ Route added for $entry ($IP) via gateway $GATEWAY with MAC $MAC_ADDRESS${NC}"
      else
        echo -e "${YELLOW}DRY RUN: Would add route for $entry ($IP) via gateway $GATEWAY with MAC $MAC_ADDRESS${NC}"
      fi
    fi
  fi

  echo "-------------------------------------------------"
done

# ==============================
# 10. End Time and Performance Measurement
# ==============================

end_time=$(date +%s)
execution_time=$((end_time - start_time))
echo -e "${BLUE}Script execution time: ${execution_time} seconds${NC}"

# ==============================
# 11. Desktop Notification
# ==============================

function send_notification() {
  local message="$1"
  osascript -e "display notification \"$message\" with title \"Ethernet Route Setup Script\""
}

send_notification "Route addition script completed successfully."

echo -e "${GREEN}✅ Ethernet route setup script completed successfully.${NC}"
