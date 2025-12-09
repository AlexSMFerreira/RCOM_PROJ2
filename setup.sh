#!/bin/bash

# This script configures the network automatically.
# It should be run with superuser privileges on any TUX.    

# Set Y as your group number.
Y=10
# Password for the remote machines
password="alanturing"

#tux_name without tux number
tux_name="netedu@tux$Y" 

# IPs
ip_tuxy2_ife1="172.16.${Y}1.1"
ip_tuxy3_ife1="172.16.${Y}0.1"
ip_tuxy4_ife1="172.16.${Y}0.254"
ip_tuxy4_ife2="172.16.${Y}1.253"

# Helper function to run commands remotely with sudo
# Usage: run_remote <tux_number> <command>
run_remote() {
    local host="${tux_name}$1"
    local cmd="$2"
    echo "Running on $host: $cmd"
    # We wrap the command in quotes so the pipe happens remotely
    sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$host" "echo $password | sudo -S $cmd"
}

# Helper to run raw commands (like for the switch serial port)
run_raw() {
    local host="${tux_name}$1"
    local cmd="$2"
    sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$host" "$cmd"
}

echo "=== Configuring TUXY2 ==="
# Set the static IP address of if_e1
run_remote 2 "ifconfig if_e1 $ip_tuxy2_ife1/24" || { echo "Error: Failed to configure TUXY2 IP"; exit 1; }
echo "TUXY2 IP configured: $ip_tuxy2_ife1/24"

echo "=== Configuring Switch ==="
# Setup the switch serial settings
run_raw 2 "stty -F /dev/ttyS0 115200 cs8 -cstopb -parenb -echo" || { echo "Error: Failed to setup switch serial port"; exit 1; }

echo "Adding bridges on switch..."
run_raw 2 "echo -e '/interface bridge add name=bridge${Y}0\r' > /dev/ttyS0"
run_raw 2 "echo -e '/interface bridge add name=bridge${Y}1\r' > /dev/ttyS0"

echo "Removing ports from default bridge..."
run_raw 2 "echo -e '/interface bridge port remove [find interface=ether12]\r' > /dev/ttyS0"
run_raw 2 "echo -e '/interface bridge port remove [find interface=ether13]\r' > /dev/ttyS0"
run_raw 2 "echo -e '/interface bridge port remove [find interface=ether14]\r' > /dev/ttyS0"
run_raw 2 "echo -e '/interface bridge port remove [find interface=ether22]\r' > /dev/ttyS0"
run_raw 2 "echo -e '/interface bridge port remove [find interface=ether24]\r' > /dev/ttyS0"

echo "Adding ports to new bridges..."
run_raw 2 "echo -e '/interface bridge port add bridge=bridge${Y}1 interface=ether12\r' > /dev/ttyS0"
run_raw 2 "echo -e '/interface bridge port add bridge=bridge${Y}0 interface=ether13\r' > /dev/ttyS0"
run_raw 2 "echo -e '/interface bridge port add bridge=bridge${Y}0 interface=ether14\r' > /dev/ttyS0"
run_raw 2 "echo -e '/interface bridge port add bridge=bridge${Y}1 interface=ether22\r' > /dev/ttyS0"
run_raw 2 "echo -e '/interface bridge port add bridge=bridge${Y}1 interface=ether24\r' > /dev/ttyS0"
echo "Switch configuration complete"

echo "=== Configuring TUXY3 ==="
run_remote 3 "ifconfig if_e1 $ip_tuxy3_ife1/24" || { echo "Error: Failed to configure TUXY3 IP"; exit 1; }
echo "TUXY3 IP configured: $ip_tuxy3_ife1/24"

echo "=== Configuring TUXY4 (Router) ==="
run_remote 4 "ifconfig if_e1 $ip_tuxy4_ife1/24" || { echo "Error: Failed to configure TUXY4 if_e1 IP"; exit 1; }
run_remote 4 "ifconfig if_e2 $ip_tuxy4_ife2/24" || { echo "Error: Failed to configure TUXY4 if_e2 IP"; exit 1; }

echo "Enabling IP forwarding and configuring ICMP..."
# Using -w for sysctl is safer
run_remote 4 "sysctl -w net.ipv4.ip_forward=1" || { echo "Error: Failed to enable IP forwarding"; exit 1; }
run_remote 4 "sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=0" || { echo "Error: Failed to configure ICMP"; exit 1; }
echo "TUXY4 router configuration complete"

echo "=== Network configuration complete ==="

read -p "Connect to Router Console. Press any key to continue..."

# Configure router via serial console (No sudo needed here usually, but handled by run_raw)
echo "Configuring Router via Serial..."
run_raw 2 "echo -e '/ip address add address=172.16.101.254/24 interface=ether2\r' > /dev/ttyS0" 
run_raw 2 "echo -e '/ip address add address=172.16.1.101/24 interface=ether1\r' > /dev/ttyS0" 
run_raw 2 "echo -e '/ip route add dst-address=172.16.100.0/24 gateway=172.16.101.253\r' > /dev/ttyS0" 

echo "=== Adding Static Routes ==="
# We use '|| true' here so the script doesn't exit if the route already exists.

# Route on TUXY3: Reach 172.16.101.0 via Router (172.16.100.254)
run_remote 3 "route add -net 172.16.101.0/24 gw 172.16.100.254" || echo "Route on TUXY3 likely exists, skipping."
run_remote 3 "route add -net 172.16.1.0/24 gw 172.16.100.254" || echo "Route on TUXY3 likely exists, skipping."

# Route on TUXY4: Reach 172.16.1.0 via Router
run_remote 4 "route add -net 172.16.1.0/24 gw 172.16.101.254" || echo "Route on TUXY4 likely exists, skipping."

# Route on TUXY2: Reach 172.16.100.0 via Router (172.16.101.253)
run_remote 2 "route add -net 172.16.100.0/24 gw 172.16.101.253" || echo "Route on TUXY2 likely exists, skipping."
run_remote 2 "route add -net 172.16.1.0/24 gw 172.16.101.254" || echo "Route on TUXY2 likely exists, skipping."

echo "Setup Finished."