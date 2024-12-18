# Ethernet Route Setup

A script to route specific domains through the active Ethernet interface while routing other internet traffic through Wi-Fi on macOS.

> [!CAUTION]
> Please ensure you fully understand how this script works before using it. Incorrect usage may modify your network configuration in unintended ways, potentially disrupting network connectivity. Proceed with caution and test in a safe environment first.


- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Automate at Login (Optional)](#automate-at-login-optional)
- [Notes](#notes)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Features

- **Automatic Ethernet Interface Detection**: Detects the active Ethernet interface dynamically.
- **Hosts File Update**: Adds specified domains to the `/etc/hosts` file. [Click to Learn More](#what-is-the-hosts-file)
- **Route Addition**: Routes traffic for specified domains through the Ethernet interface.
- **Wi-Fi as Primary Network**: Ensures other internet traffic uses Wi-Fi.
- **User-Friendly Output**: Provides colored and emoji-enhanced output for better readability.
- **Dry-Run Mode**: Allows testing the script without making any changes.
- **Desktop Notifications**: Displays a notification upon script completion.
- **Performance Measurement**: Displays the script execution time.
- **State Management**: Maintains a state file to track added domains and their associated IPs and gateways.

## What is the Hosts File?

<details>
  <summary id="what-is-the-hosts-file"><strong>Understanding Hosts files</strong></summary>

  
  The **hosts file** is a plain text file on your computer that maps domain names (like `example.com`) to IP addresses. It serves as a local, manual way to control how your computer resolves certain domain names without relying on an external DNS (Domain Name System) server.

  In macOS and Linux systems, the hosts file is typically located at `/etc/hosts`. Windows has a similar file in a different location (`C:\Windows\System32\drivers\etc\hosts`).

  ### How the Hosts File Works

  When you type a domain name (like `example.com`) into your browser, your computer first checks the hosts file to see if there’s an IP address associated with it. If the domain is found in the hosts file, your computer will use the specified IP address instead of looking it up via a DNS server on the internet. 

  For example, if your hosts file has the following entry:

  ```
  192.168.1.10 example.com
  ```

  Then whenever you try to access `example.com`, your computer will go directly to `192.168.1.10`, ignoring the DNS lookup process.

  ### Why Use the Hosts File?

  The hosts file is often used for:

  - **Testing**: Developers can use it to test websites on local servers without modifying DNS records.
  - **Overriding DNS**: It allows for overriding DNS results for specific domains, which can be helpful in network setups.
  - **Blocking Sites**: Some users add entries in the hosts file to block certain domains by pointing them to a non-existent IP.

  ### How This Script Uses the Hosts File

  This script adds entries for specified company domains to the `/etc/hosts` file. This ensures that when your computer tries to access those domains, it routes the traffic to the specific IP addresses (typically internal addresses) set in the hosts file.

  For example, adding the following entry to `/etc/hosts`:

  ```
  10.0.0.5 intranet.company.com
  ```

  would make sure that every time `intranet.company.com` is accessed on your machine, it goes to the IP `10.0.0.5`, ensuring the connection is direct and bypasses external DNS lookups.
  <br><br>
</details>

## Prerequisites

- **Operating System**: macOS
- **Administrative Privileges**: The script requires `sudo` access.


## Installation

1. **Clone the Repository and Navigate to the Directory**:

   ```bash
   git clone --depth 1 https://github.com/cs4alhaider/ethernet-route-setup.git && cd ethernet-route-setup
   ```
   
2. **Make the Script Executable**:

   ```bash
   chmod +x ethernet_route_setup.sh
   ```

3. **Configure Domains**:

    Edit the `config/domains.conf` file and list your specific domains, one per line.

     Example `domains.conf`:

     ```
     intranet.company.com
     app.company.com
     service.company.com
     ```
 4. **Configure Your Device MAC Address**:

    Edit the `config/mac_address.conf` file and put specific MAC address, this will be used if you didn't run the script with `--auto-detect` flag.

     Example `mac_address.conf`:

     ```
     c4:41:1c:76:40:fe
     ```

## Usage

- **Run the Script**:

  ```bash
  ./ethernet_route_setup.sh
  ```

- **Dry Run Mode** (No changes made):

  ```bash
  ./ethernet_route_setup.sh --dry-run
  ```

- **Specify a Custom Configuration Directory**:

  ```bash
  ./ethernet_route_setup.sh --config-dir /path/to/config
  ```

- **Auto-Detect Ethernet Interface**:

  ```bash
  ./ethernet_route_setup.sh --auto-detect
  ```

- **Display Help Information**:

  ```bash
  ./ethernet_route_setup.sh -h
  ```

## Automate at Login (Optional)

To run the script automatically when you log in:

1. **Create a Launch Agent**:

   - Save the following plist file as `net.alhaider.ethernetroutesetup.plist` in `~/Library/LaunchAgents/`:

     ```xml
     <?xml version="1.0" encoding="UTF-8"?>
     <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
     "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
     <plist version="1.0">
     <dict>
         <key>Label</key>
         <string>net.alhaider.ethernetroutesetup</string>
         <key>ProgramArguments</key>
         <array>
             <string>/bin/bash</string>
             <string>/path/to/your/ethernet_route_setup.sh</string>
         </array>
         <key>RunAtLoad</key>
         <true/>
         <key>StandardOutPath</key>
         <string>/tmp/ethernet_route_setup.sh.log</string>
         <key>StandardErrorPath</key>
         <string>/tmp/ethernet_route_setup.sh.err</string>
     </dict>
     </plist>
     ```

     - **Replace** `/path/to/your/ethernet_route_setup.sh` with the actual path to your script.

2. **Load the Launch Agent**:

   ```bash
   launchctl load ~/Library/LaunchAgents/net.alhaider.ethernetroutesetup.plist
   ```

## Notes

- **Ensure Wi-Fi is Set as Primary Network**:

  - Go to **System Preferences** > **Network**.
  - Click the **gear icon** below the list of network services.
  - Choose **Set Service Order...**.
  - Drag **Wi-Fi** to the top of the list.
  - Click **OK** and then **Apply**.

- **Security Considerations**:

  - Since the script requires `sudo`, ensure it's secured and accessible only to authorized users.
  - Keep the repository private to protect any sensitive information.

- **Testing**:

  - Use the dry-run mode to test the script without making changes.
  - Check the output logs (`/tmp/ethernet_route_setup.sh.log` and `/tmp/ethernet_route_setup.sh.err`) for any errors.

- **Multiple Ethernet Interfaces**:

  - If you have multiple active Ethernet interfaces, the script will use the first one it detects.
  - You can modify the `get_active_ethernet_interface()` function in the script to select a specific interface.

## State Management

The script utilizes a state management system to keep track of the domains, their associated IP addresses, and gateways. This is particularly useful in scenarios where the network connection may be unstable or when the device is restarted. 

When the script runs, it checks the state file to see which domains have already been processed. If a domain is found in the state file, the script can skip re-adding it, thus preventing unnecessary modifications to the `/etc/hosts` file and the routing table. 

### Why State Management is Useful

1. **Persistence Across Sessions**: The state file allows the script to remember which domains have been configured even after a reboot or disconnection. This is crucial because the routing table is reset when the device restarts, and without state management, all configurations would be lost.

2. **Efficiency**: By maintaining a record of processed domains, the script can quickly determine which entries need to be added or updated, reducing the time and resources required to execute the script.

3. **Error Handling**: If there are issues with the network connection, the state file ensures that previously successful configurations remain intact, allowing for a smoother recovery once the connection is restored.

4. **User Control**: Users can manually edit the state file if needed, providing flexibility in managing domain configurations without rerunning the entire script.

## Troubleshooting

- **No Active Ethernet Interface Found**:

  - Ensure your Ethernet connection is active and connected.
  - Check the Ethernet cable and network settings.

- **Script Fails to Add Routes**:

  - Verify that you have the necessary administrative privileges.
  - Ensure that the domains in `domains.conf` and MAC address in `mac_address.conf` are correct and reachable.

- **Desktop Notifications Not Appearing**:

  - Make sure `osascript` is available and functioning.
  - Check your notification settings in **System Preferences**.

## License

[MIT License](LICENSE)
