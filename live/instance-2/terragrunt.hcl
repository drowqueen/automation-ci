include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../..//modules/ec2"
}

inputs = {
  aws_region        = "eu-west-1"
  ami_id            = "ami-03fd334507439f4d1"  # Ubuntu 24.04 
  instance_type     = "t2.micro"
  instance_name     = "instance02"
  install_method    = "package"
  nginx_version     = "1.24.0-2ubuntu7.1"
  source_branch     = "main"
  worker_processes  = "auto"
  nginx_port        = "8080"
  server_name       = "test2"
}