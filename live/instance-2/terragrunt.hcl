include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../..//modules/ec2"
}

inputs = {
  aws_region        = "eu-west-1"
  ami_id            = "ami-0c55b159cbfafe1f0"  # Ubuntu 24.04 LTS
  instance_type     = "t2.micro"
  instance_name     = "instance-2"
  install_method    = "package"
  nginx_version     = "1.24.0"
  source_branch     = "main"
  worker_processes  = "auto"
  nginx_port        = "80"
  server_name       = "testserver"
}