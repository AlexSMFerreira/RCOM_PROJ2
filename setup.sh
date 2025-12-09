#!/bin/bash

# This script configures the network automatically.
# It should be run with superuser privileges on any TUX.

password="alanturing"

# Set Y as your group number.
Y=10

#tux_name without tux number (e.g., netedu@tux102 for TUXY2 of group 10)
tux_name="netedu@tux$Y" 

# IPs
ip_tuxy2_ife1="172.16.${Y}1.1"
ip_tuxy3_ife1="172.16.${Y}0.1"
ip_tuxy4_ife1="172.16.${Y}0.254"
ip_tuxy4_ife2="172.16.${Y}1.253"

echo "=== Configuring TUXY2 ==="
# SSH into TUXY2
sshpass -p "$password" ssh netedu@tux${Y}2
# Set the static IP address of if_e1 to 172.16.Y1.1
ifconfig if_e1 $ip_tuxy2_ife1/24
echo "TUXY2 IP configured: $ip_tuxy2_ife1/24"

echo "=== Configuring Switch ==="
# Setup the switch
stty -F /dev/ttyS0 115200 cs8 -cstopb -parenb -echo
echo "Resetting switch configuration..."
echo -e "/system reset-configuration" > /dev/ttyS0
sleep 1  # wait for prompt to appear
echo -e "y\r" > /dev/ttyUSB0
sleep 5  # wait for the system to reset

echo "Adding bridges on switch..."
# Add bridges on the switch
echo -e "/interface bridge add name=bridge${Y}0\r" > /dev/ttyS0
echo -e "/interface bridge add name=bridge${Y}1\r" > /dev/ttyS0

echo "Removing ports from default bridge..."
# Remove ports from default bridge
echo -e "/interface bridge port remove [find interface=ether12]\r" > /dev/ttyS0
echo -e "/interface bridge port remove [find interface=ether13]\r" > /dev/ttyS0
echo -e "/interface bridge port remove [find interface=ether14]\r" > /dev/ttyS0
echo -e "/interface bridge port remove [find interface=ether24]\r" > /dev/ttyS0

echo "Adding ports to new bridges..."
# Add ports to the new bridges
echo -e "/interface bridge port add bridge=bridge${Y}1 interface=ether12\r" > /dev/ttyS0
echo -e "/interface bridge port add bridge=bridge${Y}0 interface=ether13\r" > /dev/ttyS0
echo -e "/interface bridge port add bridge=bridge${Y}0 interface=ether14\r" > /dev/ttyS0
echo -e "/interface bridge port add bridge=bridge${Y}1 interface=ether24\r" > /dev/ttyS0
echo "Switch configuration complete"

# Exit TUXY2
exit

echo "=== Configuring TUXY3 ==="
# SSH into TUXY3
sshpass -p "$password" ssh netedu@tux${Y}3

# Set the static IP address of if_e1 to 172.16.Y0.1
ifconfig if_e1 $ip_tuxy3_ife1/24
echo "TUXY3 IP configured: $ip_tuxy3_ife1/24"

# Exit TUXY3
exit

echo "=== Configuring TUXY4 (Router) ==="
# SSH into TUXY4 (Router)
sshpass -p "$password" ssh netedu@tux${Y}4
# Set the static IP address of if_e1 to 172.16.Y0.254
ifconfig if_e1 $ip_tuxy4_ife1/24
echo "TUXY4 if_e1 IP configured: $ip_tuxy4_ife1/24"
# Set the static IP address of if_e2 to 172.16.Y1.253
ifconfig if_e2 $ip_tuxy4_ife2/24
echo "TUXY4 if_e2 IP configured: $ip_tuxy4_ife2/24"

echo "Enabling IP forwarding and configuring ICMP..."
# Enable IP forwarding
sysctl net.ipv4.ip_forward=1
# Disable ICMP echo ignore broadcast
sysctl net.ipv4.icmp_echo_ignore_broadcasts=0
echo "TUXY4 router configuration complete"

# Exit TUXY4
exit

echo "=== Network configuration complete ==="
