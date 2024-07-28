#!/bin/bash
username=thomas
controller_node='10.0.2.1'
managed_nodes="10.0.2.2 10.0.2.3"

echo "Adding fingerprint for $controller_node locally, if necessary"
ssh -o StrictHostKeyChecking=no -l $username $controller_node "exit"
for managed_node in $managed_nodes ; do
	echo "Adding fingerprint for $managed_node locally, if necessary"
	ssh -o StrictHostKeyChecking=no -l $username $managed_node "exit"
done

echo "Installing Ansible on node $controller_node"
#ssh -l $username $controller_node "sudo apt update ; sudo apt install ansible-core -y"
ssh -l $username $controller_node "sudo apt install ansible-core -y 1> /dev/null 2>&1"

# TODO: Should we switch to the root user?
echo "Renewing keypair to use with managed nodes"
ssh -l $username $controller_node "cd ~/.ssh ; rm ansible_ed25519 ; rm ansible_ed25519.pub; ssh-keygen -t ed25519 -C \"ansible-controller\" -f ansible_ed25519 -N \"\" -q"
public_key=$(ssh -l $username $controller_node "cat ~/.ssh/ansible_ed25519.pub")
echo "Generated public SSH key: $public_key"

# TODO: Should we switch to the root user?
for managed_node in $managed_nodes ; do
	echo "Copying public SSH key to $managed_node"
	ssh -l $username $managed_node "cd ~/.ssh ; sed -i '/^ssh-ed25519 .\\+ ansible-controller\$/d' authorized_keys ; echo \"$public_key\" >> authorized_keys"
done

echo "Installing Git on node $controller_node"
ssh -l $username $controller_node "sudo apt install git -y 1> /dev/null 2>&1"

echo "Cloning homelab-iac repository to $controller_node"
ssh -l $username $controller_node "git clone https://github.com/ThomasKasene/homelab-iac.git"
