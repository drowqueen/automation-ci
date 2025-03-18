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
  instance_name     = "instance-01"
  install_method    = "source"
  nginx_version     = "1.27.4"
  source_branch     = "main"
  worker_processes  = "auto"
  nginx_port        = "80"
  server_name       = "localhost"
}
