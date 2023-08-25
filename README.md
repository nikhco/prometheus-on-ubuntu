# automatic-carnival
terraform + ansible to setup a prometheus cluster on an Ubuntu pair in AWS

# Introduction
This project aims to showcase a simple setup - Prometheus running on two Ubuntu servers in AWS, setup in the Hierarchical federation model.
Hierarchical federation allows for one Prometheus server to aggregate data from one or more Prometheus servers which may be acting under a tree model. This enables a Primary Prometheus server to collect aggregate data from other servers in the network and showcase the health of the network as a whole.

As part of the automation effort, we are using terraform to create (and destroy) the Ubuntu servers in AWS. We are then using ansible to install and setup Prometheus (and ancillarily nginx) on the servers and to configure the Prometheus setup to monitor itself (and in the case of the Primary server, to monitor the secondary as well).


# How To
To use this repo, please follow these instructions - 
1. Create a key pair in your AWS `us-east-2` region and name it `prometheus_key_pair`. You can find the relevant page [here](https://us-east-2.console.aws.amazon.com/ec2/home?region=us-east-2#KeyPairs:). AWS will download the `.pem` file locally.
2. Create an access key under your security credentials and save the key ID and secret for later. The page to do this is [here](https://us-east-1.console.aws.amazon.com/iamv2/home?region=us-east-1#/security_credentials).
3. Ensure `terraform`, `ansible`, and `awscli v2` are installed on your system. My setup is on my Mac, so I was able to use `homebrew` to install these packages
4. Install the `prometheus` role using `ansible galaxy` with the command - `ansible-galaxy collection install prometheus.prometheus`
5. Export `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` to your terminal or save them to terraform.tfvars and import to the main.tf file
6. Run `terraform init` and then `terraform apply` (or `terraform apply -auto-approve` to skip manual agreement prompts)
7. Once the terraform setup is complete, copy the IPs of the primary and secondary servers from the output of the terraform plan
8. Check that the servers are up and running using `ssh -i prometheus_key_pair.pem ubuntu@<server_ip>` on both servers
9. Replace `<primary_ip>` and `<secondary_ip>` in the `inventory.ini` and the `prometheus_config.yaml` files. Ensure the path of the `prometheus_key_pair.pem` file is correct.
10. Now, you can run ansible, with the command `ansible-playbook -i inventory.ini prometheus.yaml`
11. Once the ansible setup is complete, you can now visit the Prometheus servers on port `9090` of the public IPs of the servers to view the data being collected. The graphs on the Primary server will include data from the Secondary server as well. My favorite to look at is `process_cpu_seconds_total`, which shows the CPU usage of the Prometheus servers over time.
12. Once your work is complete, don't forget to wipe the AWS resources using `terraform destroy -auto-approve` to ensure you're not footing an unnecessary bill 🙂

# File Structure
The relevant files in this repo are as follows - 
- README.md - this file, it contains information about the overall goals of the project, as well as instructions on how to execute it locally
- main.tf - this is the file used by terraform to create the resources in AWS. As mentioned before, credentials and the setup of the awscli are not part of this file and should be setup manually beforehand.
- prometheus.yaml - this is the file used by ansible to create the necessary resources inside the Ubuntu servers once they're up and running. It installs Prometheus and nginx, setups up monitoring, and reloads Prometheus to ensure the configuration is accepted.
- prometheus_config.yaml - this and `prometheus_config_secondary.yaml` are files used by ansible to configure the data scrape jobs performed by Prometheus in the Primary and Secondary servers.
- inventory.ini - this file is where the crendentials and IPs of the servers is stored for ansible to use to configure the servers. It must be manually populated after terraform outputs the relevant information upon successful completion.

# Further Possible Improvements
There are a variety of improvements we can do to this setup. They largely fall into two buckets, somewhat corresponding to what we do in ansible and in terraform

## Infrastructure improvements
1. Make the setup more secure
	- We should not be exposing the default SSH port to the open internet
	- We should potentially use a jumphost (preferable a spot instance jump host) to connect to the other servers in the network
	- Consider whether this entire VPC needs any direct internet connectivity. Can it connect via a VPN connection to make it more secure?
2. Consider connecting Prometheus not over the public IP but over the Private IP of the servers.
3. Can Prometheus itself be secured via passwords/API access keys?
4. Remove all hardcoding - the region, the AMI ID, ports for Prometheus, SSH, and nginx, CIDR block for the VPC private IP range should all be configurable and user supplied, with reasonable defaults assumed. Instance type and Spot options should also be programmable.
5. Add checks in terraform to wait till the servers are actually provisioned and up and running. Right now, we have to manually check that the servers are working before running ansible, or ansible fails to perform the tasks.
 
## Automation improvements
1. A CI/CD pipeline to automate the terraform and ansible execution
2. To achieve the CI pipeline, we also need to be able to pass public and private IP data (and any other relevant information) from terraform to Ansible. Consider writing a simple script or to use terraform file writing capabilities to write to the inventory.ini and the prometheus_config.yaml files
3. Also, two separate files for the Prometheus configuration should not be needed. Consider using Jinja to templatize the setup. There is a benefit to using two separate files though - it's amply clear that the Primary server needs to aggregate data from all secondary servers. So a simple non-template config for the secondary servers (which allows them to only monitor themselves) makes sense.
4. Automate AWS resource destruction at the end of the test cycle (if there is testing involved)
