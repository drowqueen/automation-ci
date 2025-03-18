terraform {
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

resource "aws_security_group" "nginx_sg" {
  name        = "nginx-sg-${var.instance_name}"
  description = "Allow SSH and Nginx traffic"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = var.nginx_port
    to_port     = var.nginx_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "nginx_instance" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.nginx_sg.id]
  user_data     = <<-EOF
                  #!/bin/bash
                  apt-get update
                  apt-get install -y ruby git
                  gem install chef --no-document
                  mkdir -p /opt/chef
                  cd /opt/chef
                  curl -L https://github.com/chef/chef/archive/refs/tags/v17.10.0.tar.gz | tar xz --strip-components=1
                  echo 'cookbook_path "/opt/chef/cookbooks"' > solo.rb
                  mkdir -p cookbooks/nginx_install/recipes
                  mkdir -p cookbooks/nginx_install/templates
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/recipes/default.rb"))}' | base64 -d > cookbooks/nginx_install/recipes/default.rb
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/recipes/package_install.rb"))}' | base64 -d > cookbooks/nginx_install/recipes/package_install.rb
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/recipes/source_install.rb"))}' | base64 -d > cookbooks/nginx_install/recipes/source_install.rb
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/templates/nginx.conf.erb"))}' | base64 -d > cookbooks/nginx_install/templates/nginx.conf.erb
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/templates/nginx.service.erb"))}' | base64 -d > cookbooks/nginx_install/templates/nginx.service.erb
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/metadata.rb"))}' | base64 -d > cookbooks/nginx_install/metadata.rb
                  ls -R cookbooks/nginx_install/ > /tmp/cookbook_files.txt
                  echo '{ "install_method": "${var.install_method}", "nginx_version": "${var.nginx_version}", "worker_processes": "${var.worker_processes}", "listen_port": "${var.nginx_port}", "server_name": "${var.server_name}" }' > attributes.json
                  chef-solo -c solo.rb -j attributes.json -o nginx_install::default -l debug > /tmp/chef_output.txt 2>&1 || echo "Chef failed" > /tmp/chef_error.txt
                  dpkg -l | grep nginx > /tmp/nginx_check.txt 2>&1 || echo "Nginx not installed" >> /tmp/nginx_check.txt
                  systemctl status nginx > /tmp/nginx_status.txt 2>&1 || true
                  EOF

  tags = {
    Name = var.instance_name
  }
}