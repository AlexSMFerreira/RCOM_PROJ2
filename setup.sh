#!/bin/bash

# This script configures the network automatically.
# It should be run with superuser privileges on any TUX.    

# Set Y as your group number.
Y=10

#tux_name without tux number (e.g., netedu@tux102 for TUXY2 of group 10)
tux_name="netedu@tux$Y" 
password="alanturing"

# IPs
ip_tuxy2_ife1="172.16.${Y}1.1"
ip_tuxy3_ife1="172.16.${Y}0.1"
ip_tuxy4_ife1="172.16.${Y}0.254"
ip_tuxy4_ife2="172.16.${Y}1.253"

echo "=== Configuring TUXY2 ==="
echo "$password"
# Set the static IP address of if_e1 to 172.16.Y1.1
sshpass -p $password ssh -o StrictHostKeyChecking=no ${tux_name}2 echo $password | sudo -S ifconfig if_e1 $ip_tuxy2_ife1/24 || { echo "Error: Failed to configure TUXY2 IP"; exit 1; }
echo "TUXY2 IP configured: $ip_tuxy2_ife1/24"

echo "=== Configuring Switch ==="
# Setup the switch
sshpass -p $password ssh -o StrictHostKeyChecking=no ${tux_name}2 stty -F /dev/ttyS0 115200 cs8 -cstopb -parenb -echo || { echo "Error: Failed to setup switch serial port"; exit 1; }

echo "Adding bridges on switch..."
# Add bridges on the switch
sshpass -p $password ssh -o StrictHostKeyChecking=no ${tux_name}2 "echo -e '/interface bridge add name=bridge${Y}0\r' > /dev/ttyS0" || { echo "Error: Failed to add bridge${Y}0"; exit 1; }
sshpass -p $password ssh -o StrictHostKeyChecking=no ${tux_name}2 "echo -e '/interface bridge add name=bridge${Y}1\r' > /dev/ttyS0" || { echo "Error: Failed to add bridge${Y}1"; exit 1; }

echo "Removing ports from default bridge..."
# Remove ports from default bridge
sshpass -p $password ssh -o StrictHostKeyChecking=no ${tux_name}2 "echo -e '/interface bridge port remove [find interface=ether12]\r' > /dev/ttyS0" || { echo "Error: Failed to remove ether12 from default bridge"; exit 1; }
sshpass -p $password ssh -o StrictHostKeyChecking=no ${tux_name}2 "echo -e '/interface bridge port remove [find interface=ether13]\r' > /dev/ttyS0" || { echo "Error: Failed to remove ether13 from default bridge"; exit 1; }
sshpass -p $password ssh -o StrictHostKeyChecking=no ${tux_name}2 "echo -e '/interface bridge port remove [find interface=ether14]\r' > /dev/ttyS0" || { echo "Error: Failed to remove ether14 from default bridge"; exit 1; }
sshpass -p $password ssh -o StrictHostKeyChecking=no ${tux_name}2 "echo -e '/interface bridge port remove [find interface=ether24]\r' > /dev/ttyS0" || { echo "Error: Failed to remove ether24 from default bridge"; exit 1; }

echo "Adding ports to new bridges..."
# Add ports to the new bridges
sshpass -p $password ssh -o StrictHostKeyChecking=no ${tux_name}2 "echo -e '/interface bridge port add bridge=bridge${Y}1 interface=ether12\r' > /dev/ttyS0" || { echo "Error: Failed to add ether12 to bridge${Y}1"; exit 1; }
sshpass -p $password ssh -o StrictHostKeyChecking=no ${tux_name}2 "echo -e '/interface bridge port add bridge=bridge${Y}0 interface=ether13\r' > /dev/ttyS0" || { echo "Error: Failed to add ether13 to bridge${Y}0"; exit 1; }
sshpass -p $password ssh -o StrictHostKeyChecking=no ${tux_name}2 "echo -e '/interface bridge port add bridge=bridge${Y}0 interface=ether14\r' > /dev/ttyS0" || { echo "Error: Failed to add ether14 to bridge${Y}0"; exit 1; }
sshpass -p $password ssh -o StrictHostKeyChecking=no ${tux_name}2 "echo -e '/interface bridge port add bridge=bridge${Y}1 interface=ether24\r' > /dev/ttyS0" || { echo "Error: Failed to add ether24 to bridge${Y}1"; exit 1; }
echo "Switch configuration complete"

echo "=== Configuring TUXY3 ==="
# Set the static IP address of if_e1 to 172.16.Y0.1
sshpass -p $password ssh -o StrictHostKeyChecking=no ${tux_name}3 echo $password | sudo -S ifconfig if_e1 $ip_tuxy3_ife1/24 || { echo "Error: Failed to configure TUXY3 IP"; exit 1; }
echo "TUXY3 IP configured: $ip_tuxy3_ife1/24"

echo "=== Configuring TUXY4 (Router) ==="
# Set the static IP address of if_e1 to 172.16.Y0.254
sshpass -p $password ssh -o StrictHostKeyChecking=no ${tux_name}4 echo $password | sudo -S ifconfig if_e1 $ip_tuxy4_ife1/24 || { echo "Error: Failed to configure TUXY4 if_e1 IP"; exit 1; }
echo "TUXY4 if_e1 IP configured: $ip_tuxy4_ife1/24"
# Set the static IP address of if_e2 to 172.16.Y1.253
sshpass -p $password ssh -o StrictHostKeyChecking=no ${tux_name}4 echo $password | sudo -S ifconfig if_e2 $ip_tuxy4_ife2/24 || { echo "Error: Failed to configure TUXY4 if_e2 IP"; exit 1; }
echo "TUXY4 if_e2 IP configured: $ip_tuxy4_ife2/24"

echo "Enabling IP forwarding and configuring ICMP..."
# Enable IP forwarding
sshpass -p $password ssh -o StrictHostKeyChecking=no ${tux_name}4 sysctl net.ipv4.ip_forward=1 || { echo "Error: Failed to enable IP forwarding"; exit 1; }
# Disable ICMP echo ignore broadcast
sshpass -p $password ssh -o StrictHostKeyChecking=no ${tux_name}4 sysctl net.ipv4.icmp_echo_ignore_broadcasts=0 || { echo "Error: Failed to configure ICMP"; exit 1; }
echo "TUXY4 router configuration complete"

echo "=== Network configuration complete ==="
