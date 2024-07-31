#!/bin/bash
username=thomas
master_node_ip='10.0.2.1'
worker_nodes="10.0.2.2 10.0.2.3"

master_node_url="https://$master_node_ip:6443"

init_script="sudo su - -c \"sed -i 's/\\$/ cgroup_memory=1 cgroup_enable=memory/' /boot/firmware/cmdline.txt ; reboot\""
echo "Configuring cgroups on master node $master_node_ip"
ssh -o StrictHostKeyChecking=no -l $username $master_node_ip $init_script
for worker_node in $worker_nodes ; do
	echo "Configuring cgroups on worker node $worker_node"
	ssh -o StrictHostKeyChecking=no -l $username $worker_node $init_script
done
echo "Node(s) are restarting"

rebooted=false
while [ "$rebooted" = false ] ; do
	sleep 5
	ssh -l $username $master_node_ip "exit"
	if [ "$?" = 0 ] ; then
		rebooted=true
	fi
done
echo "Master node $master_node_ip has restarted"

echo "Installing k3s server on master node $master_node_ip"
ssh -l $username $master_node_ip "sudo curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE=\"644\" sh - > /dev/null"
master_token=$(ssh -l $username $master_node_ip "sudo cat /var/lib/rancher/k3s/server/node-token")

for worker_node in $worker_nodes ; do
	echo "Installing k3s agent on worker node $worker_node"
	ssh -l $username $worker_node "sudo curl -sfL https://get.k3s.io | K3S_TOKEN=\"$master_token\" K3S_URL=\"$master_node_url\" sh - > /dev/null"
done
