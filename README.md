# AWS Auto Scaling Group with Terraform

This is a lab that creates an Auto Scaling Group in AWS using Terraform.

It then tests this auto scaling by running an Ansible playbook that downloads and runs stress, a workload generator.

To see if the auto scaling worked, I set up an SQS queue that receives messages from the Auto Scaling group via SNS about updates in the group (instances launched, terminated, etc.)

TODO: Make the SQS queue messages do something interesting — notified via a web app, email, text message, etc.