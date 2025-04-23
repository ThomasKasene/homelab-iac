#!/bin/bash

function log_usage {
        echo "Usage: $0 <ansible_username>"
}

if [[ "$#" != 1 ]]; then
        echo "Invalid number of parameters"
        log_usage
        exit 1
fi

ansible_username=$1

sudo su $ansible_username

cd ~/

sudo su ansible -c 'cd ~/homelab-iac ; ansible-playbook ~/homelab-iac/site.yml'
