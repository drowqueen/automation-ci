include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../..//modules/ec2"
}

inputs = {
  aws_region        = "eu-west-1"
  ami_id            = "ami-0ff20c640f06d85cf"  # Ubuntu 24.04 LTS
  instance_type     = "t2.micro"
  instance_name     = "instance-1"
  install_method    = "source"
  nginx_version     = "1.27.4"
  source_branch     = "main"
  worker_processes  = "auto"
  nginx_port        = "8080"
  server_name       = "localhost"
}
