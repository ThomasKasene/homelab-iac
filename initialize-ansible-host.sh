#!/bin/bash

# Pre-requisites:
# 1. Two nodes; one to be the control node, and another having the role of host node
# 2. Both nodes should have an existing user with SSH access, and use public/private key pairs for authentication
# 3. SSH users should also have not need to enter a password to use sudo

function log_usage {
	echo "Usage: $0 <control_node_ipv4> <control_node_ssh_user> <host_node_ipv4> <host_node_ssh_user>"
}

function is_valid_ipv4_address {
	if [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
		true
	else
		false
	fi
}

if [[ "$#" != 4 ]]; then
	echo "Invalid number of parameters"
	log_usage
	exit 1
fi

if ! is_valid_ipv4_address $1; then
	echo "control_node_ipv4 is not a valid IPv4 address"
	log_usage
	exit 1
fi

if ! [ -z "$3" ] && ! is_valid_ipv4_address $3; then
	echo "host_node_ipv4 is not a valid IPv4 address"
	log_usage
	exit 1
fi

control_node_ip=$1
control_node_ssh_username=$2
host_node_ip=$3
host_node_ssh_username=$4

ansible_username="ansible"
repository_git_url=https://github.com/ThomasKasene/homelab-iac.git
repository_name=homelab-iac

function ssh_control_node {
        ssh -l $control_node_ssh_username $control_node_ip "$1"
}

function log_control_node {
        echo "[$control_node_ip] $1"
}

function ssh_host_node {
	ssh -l $host_node_ssh_username $host_node_ip "$1"
}

function log_host_node {
	echo "[$host_node_ip] $1"
}

# Step 1: Add fingerprint of the nodes involved
ssh -l $control_node_ssh_username $control_node_ip -o StrictHostKeyChecking=no -o LogLevel=ERROR "exit"
ssh -l $host_node_ssh_username $host_node_ip -o StrictHostKeyChecking=no -o LogLevel=ERROR "exit"

# Step 2: Set up the ansible user on the control node, if necessary
if ! $(ssh_control_node "sudo id -u $ansible_username &>/dev/null"); then
        log_control_node "Creating the $ansible_username user"
        ssh_control_node "sudo useradd $ansible_username --groups sudo --create-home --system"
fi

if ! $(ssh_control_node "test -e /etc/sudoers.d/$ansible_username"); then
        log_control_node "Creating sudoers.d file for the $ansible_username user"
        ssh_control_node "sudo touch /etc/sudoers.d/$ansible_username"
fi

if ! [[ $(ssh_control_node "sudo cat /etc/sudoers.d/$ansible_username") == "$ansible_username ALL=(ALL) NOPASSWD: ALL" ]]; then
        log_control_node "Configuring the $ansible_username user in sudoers.d"
        ssh_control_node "sudo su root -c 'echo \"$ansible_username ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/$ansible_username'"
fi

if ! $(ssh_control_node "sudo su $ansible_username -c 'test -e ~/.ssh'"); then
        log_control_node "Creating .ssh directory for the $ansible_username user"
        ssh_control_node "sudo su $ansible_username -c 'mkdir -m 700 ~/.ssh'"
fi

if ! $(ssh_control_node "sudo test -e /home/$ansible_username/.ssh/${ansible_username}_ed25519.pub"); then
	log_control_node "Generating key/value pair for the $ansible_username user"
	ssh_control_node "sudo su $ansible_username -c 'ssh-keygen -t ed25519 -C \"ansible-controller\" -f ~/.ssh/${ansible_username}_ed25519 -N \"\" -q'"
fi

if ! $(ssh_control_node "sudo test -e /home/$ansible_username/.ssh/authorized_keys"); then
	log_control_node "Creating authorized_keys for the $ansible_username user"
	ssh_control_node "sudo su $ansible_username -c 'touch ~/.ssh/authorized_keys'"
fi

public_key=$(ssh_control_node "sudo cat /home/$ansible_username/.ssh/${ansible_username}_ed25519.pub")

if ! $(ssh_control_node "sudo su $ansible_username -c 'grep -Fxq \"$public_key\" ~/.ssh/authorized_keys'"); then
	log_control_node "Adding control node's public key to authorized keys"
	ssh_control_node "sudo su $ansible_username -c 'echo \"$public_key\" | tee -a ~/.ssh/authorized_keys > /dev/null'"
fi

if ! $(ssh_control_node "sudo test -e /home/$ansible_username/.ssh/known_hosts"); then
	log_control_node "Creating known_hosts for the $ansible_username user"
	ssh_control_node "sudo su $ansible_username -c 'touch ~/.ssh/known_hosts'"
fi

ssh_control_node "sudo su $ansible_username -c 'ssh -i ~/.ssh/${ansible_username}_ed25519 -o StrictHostKeyChecking=no -o LogLevel=ERROR -l $ansible_username $control_node_ip \"exit\"'"

# Step 4: Set up the ansible user on the host node, if necessary
if ! $(ssh_host_node "sudo id -u $ansible_username &>/dev/null"); then
	log_host_node "Creating the $ansible_username user"
	ssh_host_node "sudo useradd $ansible_username --groups sudo --create-home --system"
fi

if ! $(ssh_host_node "test -e /etc/sudoers.d/$ansible_username"); then
	log_host_node "Creating sudoers.d file for the $ansible_username user"
	ssh_host_node "sudo touch /etc/sudoers.d/$ansible_username"
fi

if ! [[ $(ssh_host_node "sudo cat /etc/sudoers.d/$ansible_username") == "$ansible_username ALL=(ALL) NOPASSWD: ALL" ]]; then
	log_host_node "Configuring the $ansible_username user in sudoers.d"
	ssh_host_node "sudo su root -c 'echo \"$ansible_username ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/$ansible_username'"
fi

if ! $(ssh_host_node "sudo su $ansible_username -c 'test -e ~/.ssh'"); then
	log_host_node "Creating .ssh directory for the $ansible_username user"
	ssh_host_node "sudo su $ansible_username -c 'mkdir -m 700 ~/.ssh'"
fi

if ! $(ssh_host_node "sudo su $ansible_username -c 'test -e ~/.ssh/authorized_keys'"); then
	log_host_node "Creating authorized_keys for the $ansible_username user"
	ssh_host_node "sudo su $ansible_username -c 'touch ~/.ssh/authorized_keys'"
fi

if ! $(ssh_host_node "sudo su $ansible_username -c 'grep -Fxq \"$public_key\" ~/.ssh/authorized_keys'"); then
	log_host_node "Adding control node's public key to authorized keys"
	ssh_host_node "sudo su $ansible_username -c 'echo \"$public_key\" | tee -a ~/.ssh/authorized_keys > /dev/null'"
fi

ssh_control_node "sudo su $ansible_username -c 'ssh -i ~/.ssh/${ansible_username}_ed25519 -o StrictHostKeyChecking=no -o LogLevel=ERROR -l $ansible_username $host_node_ip \"exit\"'"
