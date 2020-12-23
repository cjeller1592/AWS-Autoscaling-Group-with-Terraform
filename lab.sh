#!/bin/bash

terraform init

echo "Creating the Auto scaling group ..."

terraform apply --auto-approve

echo "Done!"

sleep 5

echo "Getting IP address of EC2 instance for hosts.ini file..."

stuff=`aws ec2 describe-instances \
--filters Name=tag-key,Values=foo Name=instance-state-name,Values=running \
--query 'Reservations[*].Instances[*].[PublicIpAddress]' \
--output text`

echo "[webservers]
$stuff" > hosts.ini

echo "Done!"

sleep 5

echo "Running Ansible playbook ..."

ansible-playbook -i hosts.ini playbook.yml --private-key /Users/cjeller/.ssh/my-key-pair.pem

echo "Done! Let's check in on the AWS console to see if more instances pop up in the Auto Scaling group ..."