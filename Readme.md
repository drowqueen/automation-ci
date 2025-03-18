This repository automates the deployment of Nginx instances on AWS EC2 using Terraform, Terragrunt, and GitHub Actions. It supports both package and source installation methods for Nginx, with a focus on folder-agnostic logic under the live/ directory.

# Prerequisites 
* AWS Credentials: Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in GitHub Secrets.
* ssh key for the instances from aws 
* Terraform: Version 1.8.0
* Terragrunt: Version 0.55.1 

# Deploying a new instance
Create a new instance folder under live/ with instance name and terragrunt.hcl definition using the module in modules/ec2. Select one of the two methods available to install nginx: package and source.

Example: 
```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/ec2"
}

inputs = {
  aws_region        = "eu-west-1"
  ami_id            = "ami-0e7019515e31818f8"  # Ubuntu 20.04 LTS
  instance_type     = "t2.micro"
  key_name          = "my-key-pair"
  instance_name     = "nginx-instance-2"
  install_method    = "package"                # or "source"
  nginx_version     = "1.18.0-0ubuntu1.4"
  source_branch     = "main"
  worker_processes  = "auto"
  nginx_port        = "80"
  server_name       = "testserver"
}
```
Push changes to the branch, when the branch is merged it will trigger the github actions and launch a new instance with the selected method or modify an existing instance's configuration.

# Testing nginx installation

Check the GitHub Actions workflow logs or use terragrunt output command in live/instance-name folder to retrieve the public IP.  Run the test script from repo root using the parameters you provided and the public IP of the instance:
````
./scripts/test-nginx.sh <NGINX Version> <port> <server_name> <public_IP> <install_method> /path/to/ssh-key-pair
```




