#!/bin/bash
username=thomas
controller_node='10.0.2.1'
managed_nodes="10.0.2.1 10.0.2.2 10.0.2.3"
#managed_nodes="10.0.2.1"

for managed_node in $managed_nodes ; do
	echo "[localhost] Adding fingerprint for $managed_node, if necessary"
	ssh -o StrictHostKeyChecking=no -l $username $managed_node "exit"

	echo "[$managed_node] Creating the ansible user"
	ssh -l $username $managed_node "sudo useradd ansible --groups sudo --create-home --system 1> /dev/null 2>&1"

	echo "[$managed_node] Creating sudoers.d file for ansible user"
	ssh -l $username $managed_node "sudo su root -c 'sudo touch /etc/sudoers.d/ansible ; echo \"ansible ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/ansible'"

	echo "[$managed_node] Creating ~/.ssh for the ansible user"
	ssh -l $username $managed_node "sudo su ansible -c 'mkdir -m 700 ~/.ssh' 1> /dev/null 2>&1"

	echo "[$managed_node] Creating ~/.ssh/authorized_keys for the ansible user"
	ssh -l $username $managed_node "sudo su ansible -c 'touch ~/.ssh/authorized_keys'"
done

echo "[$controller_node] Renewing key pair to use with managed nodes"
ssh -l $username $controller_node "sudo su ansible -c 'cd ~/.ssh ; rm ansible_ed25519 ansible_ed25519.pub ; ssh-keygen -t ed25519 -C \"ansible-controller\" -f ansible_ed25519 -N \"\" -q'"
public_key=$(ssh -l $username $controller_node "sudo cat /home/ansible/.ssh/ansible_ed25519.pub")

for managed_node in $managed_nodes ; do
	echo "[$managed_node] Authorizing $controller_node's public SSH key"
	ssh -l $username $managed_node "sudo sed -i '/^ssh-ed25519 .\\+ ansible-controller\$/d' /home/ansible/.ssh/authorized_keys ; echo \"$public_key\" | sudo tee -a /home/ansible/.ssh/authorized_keys > /dev/null"

	echo "[$controller_node] Adding fingerprint for $managed_node, if necessary"
	ssh -l $username $controller_node "sudo su ansible -c 'ssh -i ~/.ssh/ansible_ed25519 -o StrictHostKeyChecking=no -l ansible $managed_node \"exit\"'"
done

echo "[$controller_node] Updating package cache"
ssh -l $username $controller_node "sudo apt update 1> /dev/null 2>&1"

echo "[$controller_node] Installing Ansible"
ssh -l $username $controller_node "sudo apt install ansible-core -y 1> /dev/null 2>&1"

echo "[$controller_node] Installing Git"
ssh -l $username $controller_node "sudo apt install git -y 1> /dev/null 2>&1"

echo "[$controller_node] Cloning homelab-iac repository"
ssh -l $username $controller_node "sudo su ansible -c 'rm -rf ~/homelab-iac ; git clone https://github.com/ThomasKasene/homelab-iac.git ~/homelab-iac' 1> /dev/null 2>&1"

echo "[$controller_node] Running Ansible playbook site.yml"
ssh -l $username $controller_node "sudo su ansible -c 'cd ~/homelab-iac ; ansible-playbook ~/homelab-iac/site.yml'"
