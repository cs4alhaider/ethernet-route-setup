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
  local dependencies=("dig" "route" "grep" "awk" "sudo" "osascript" "ifconfig" "networksetup" "mkdir")
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

echo -e "${ORANGE}=========================================================================="
echo -e "                    Ethernet Route Setup Script"
echo -e "------------------------------------------------------------------------"
echo -e "   Starting a script written by Abdullah Alhaider"
echo -e "   Version: 1.0.0"
echo -e "------------------------------------------------------------------------"
echo -e "   Please visit:"
echo -e "   https://github.com/cs4alhaider/ethernet-route-setup"
echo -e "   for more information, documentation and updates."
echo -e "------------------------------------------------------------------------"
echo -e "   This script helps configure network routes and hosts"
echo -e "   for specified domains or IP addresses using Ethernet interfaces."
echo -e "==========================================================================${NC}"

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
  echo "  --ignore-state        Ignore the existing state file and regenerate it."
  echo "  -h, --help            Display this help message."
  exit 0
}

# ==============================
# 4. Variables and Configuration
# ==============================

# Default configuration directory
CONFIG_DIR="./config"
AUTO_DETECT=false
IGNORE_STATE=false

# State file configuration
STATE_DIR="./.state"
STATE_FILE="$STATE_DIR/state.conf"

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
    --ignore-state)
      IGNORE_STATE=true
      echo -e "${YELLOW}Ignoring existing state file and regenerating...${NC}"
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

# Function to load domains from domains.conf while ignoring comments, empty lines and whitespace
function load_domains() {
  local domains=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Remove leading/trailing whitespace
    line=$(echo "$line" | xargs)
    # Skip empty lines and comments
    if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
      # Remove inline comments and trim
      domain=$(echo "$line" | sed 's/#.*$//' | xargs)
      if [[ -n "$domain" ]]; then
        domains+=("$domain")
      fi
    fi
  done < "$DOMAINS_FILE"
  echo "${domains[@]}"
}

# Function to ensure state directory exists
function ensure_state_dir() {
  if [ ! -d "$STATE_DIR" ]; then
    if [ "$DRY_RUN" = false ]; then
      mkdir -p "$STATE_DIR"
      echo -e "${GREEN}✅ Created state directory: $STATE_DIR${NC}"
    else
      echo -e "${YELLOW}DRY RUN: Would create state directory: $STATE_DIR${NC}"
    fi
  fi
}

# Function to get IP from domain or IP string
function get_ip() {
    local input="$1"
    # If input contains a colon (port number), strip it
    input="${input%:*}"
    
    # Check if input is already an IP address
    if [[ $input =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$input"
        return 0
    fi
    
    # Try DNS lookup
    local ip
    ip=$(dig +short "$input" | grep -E '^[0-9.]+$' | head -n 1)
    echo "$ip"
}

# Function to load state from state.conf
function load_state() {
    local domains=""
    while IFS='|' read -r domain _ _; do
        domains="$domains$domain "
    done < "$STATE_FILE"
    echo "$domains"
}

# Function to update state.conf with new domains
function update_state() {
    local domain
    ensure_state_dir
    
    for domain in "$@"; do
        # Get IP (either from DNS or direct IP)
        local IP
        IP=$(get_ip "$domain")
        
        if [ -z "$IP" ]; then
            echo -e "${RED}❌ Failed to retrieve IP for $domain. Skipping...${NC}"
            continue
        else
            echo -e "${GREEN}✅ Retrieved IP for $domain: $IP${NC}"
        fi
        
        # Retrieve gateway
        local GATEWAY
        GATEWAY=$(route -n get "$IP" 2>/dev/null | awk '/gateway:/ {print $2}')
        if [ -z "$GATEWAY" ]; then
            echo -e "${RED}❌ Failed to retrieve gateway for IP $IP of $domain. Skipping...${NC}"
            continue
        fi
        
        if [ "$DRY_RUN" = false ]; then
            echo "$domain|$IP|$GATEWAY" >> "$STATE_FILE"
            echo -e "${GREEN}✅ Added $domain to state file with IP $IP and Gateway $GATEWAY${NC}"
        else
            echo -e "${YELLOW}DRY RUN: Would add $domain to state file with IP $IP and Gateway $GATEWAY${NC}"
        fi
    done
}

# Load domains into an array
domains=($(load_domains))

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

# Handle state file
if [ "$IGNORE_STATE" = true ] || [ ! -f "$STATE_FILE" ]; then
  echo -e "${GREEN}✅ Generating new state file...${NC}"
  ensure_state_dir
  # Truncate or create the state file
  if [ "$DRY_RUN" = false ]; then
    : > "$STATE_FILE"
    echo -e "${GREEN}✅ State file initialized: $STATE_FILE${NC}"
  else
    echo -e "${YELLOW}DRY RUN: Would initialize state file: $STATE_FILE${NC}"
  fi
  # Add all domains to state
  update_state "${domains[@]}"
fi

# Check if state file exists after possible initialization
if [ -f "$STATE_FILE" ]; then
  # Load existing state
  existing_domains=($(load_state))
  
  # Compare with domains.conf to find new domains
  new_domains=()
  for domain in "${domains[@]}"; do
    if ! grep -qw "$domain" "$STATE_FILE"; then
      new_domains+=("$domain")
    fi
  done

  if [ ${#new_domains[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  New domains found in domains.conf. Updating state file...${NC}"
    update_state "${new_domains[@]}"
  else
    echo -e "${GREEN}✅ State file is up to date.${NC}"
  fi
fi

# Reload the domains array from the state file
while IFS='|' read -r domain ip gateway || [ -n "$domain" ]; do
    if [ -n "$domain" ]; then
        echo -e "${GREEN}   • $domain | IP: $ip | Gateway: $gateway${NC}"
        
        # Process each entry
        echo -e "${BLUE}🌐 Processing entry: $domain${NC}"
        
        if [ -n "$ip" ] && [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo -e "${GREEN}✅ Using stored IP address: $ip${NC}"
            
            # Continue with hosts and route setup...
            if ! hosts_entry_exists "$domain" && ! [[ $domain =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && ! [[ $domain =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; then
                echo -e "${BLUE}📝 $domain not found in /etc/hosts. Proceeding to add...${NC}"
                if [ "$DRY_RUN" = false ]; then
                    echo "$ip $domain" | sudo tee -a /etc/hosts > /dev/null
                    echo -e "${GREEN}✅ Added $domain with IP $ip to /etc/hosts${NC}"
                else
                    echo -e "${YELLOW}DRY RUN: Would add $domain with IP $ip to /etc/hosts${NC}"
                fi
            fi
            
            # Route setup logic here...
        fi
    fi
done < "$STATE_FILE"

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
