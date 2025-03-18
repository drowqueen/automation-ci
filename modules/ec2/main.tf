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
                  echo "Starting user_data script" > /tmp/user_data.log
                  apt-get update >> /tmp/user_data.log 2>&1 || { echo "apt-get update failed"; exit 1; }
                  apt-get install -y ruby ruby-dev build-essential >> /tmp/user_data.log 2>&1 || { echo "apt-get install ruby ruby-dev build-essential failed"; exit 1; }
                  gem install chef --no-document >> /tmp/user_data.log 2>&1 || { echo "gem install chef failed"; exit 1; }
                  # Ensure chef-solo is in PATH
                  export PATH=$PATH:/usr/local/bin:/var/lib/gems/*/bin >> /tmp/user_data.log 2>&1
                  which chef-solo >> /tmp/user_data.log 2>&1 || { echo "chef-solo not found after install"; exit 1; }
                  mkdir -p /opt/chef >> /tmp/user_data.log 2>&1
                  cd /opt/chef
                  curl -L https://github.com/chef/chef/archive/refs/tags/v17.10.0.tar.gz | tar xz --strip-components=1 >> /tmp/user_data.log 2>&1 || { echo "chef download failed"; exit 1; }
                  echo 'cookbook_path "/opt/chef/cookbooks"' > solo.rb
                  mkdir -p cookbooks/nginx_install/recipes
                  mkdir -p cookbooks/nginx_install/templates
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/recipes/default.rb"))}' | base64 -d > cookbooks/nginx_install/recipes/default.rb 2>> /tmp/user_data.log
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/recipes/package_install.rb"))}' | base64 -d > cookbooks/nginx_install/recipes/package_install.rb 2>> /tmp/user_data.log
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/recipes/source_install.rb"))}' | base64 -d > cookbooks/nginx_install/recipes/source_install.rb 2>> /tmp/user_data.log
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/templates/nginx.conf.erb"))}' | base64 -d > cookbooks/nginx_install/templates/nginx.conf.erb 2>> /tmp/user_data.log
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/templates/nginx.service.erb"))}' | base64 -d > cookbooks/nginx_install/templates/nginx.service.erb 2>> /tmp/user_data.log
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/metadata.rb"))}' | base64 -d > cookbooks/nginx_install/metadata.rb 2>> /tmp/user_data.log
                  ls -R cookbooks/nginx_install/ > /tmp/cookbook_files.txt 2>> /tmp/user_data.log
                  echo '{ "install_method": "${var.install_method}", "nginx_version": "${var.nginx_version}", "worker_processes": "${var.worker_processes}", "listen_port": "${var.nginx_port}", "server_name": "${var.server_name}" }' > attributes.json 2>> /tmp/user_data.log
                  chef-solo -c solo.rb -j attributes.json -o nginx_install::default -l debug > /tmp/chef_output.txt 2>&1 || echo "Chef failed" > /tmp/chef_error.txt
                  dpkg -l | grep nginx > /tmp/nginx_check.txt 2>&1 || echo "Nginx not installed" >> /tmp/nginx_check.txt
                  systemctl status nginx > /tmp/nginx_status.txt 2>&1 || true
                  echo "user_data script completed" >> /tmp/user_data.log
                  EOF

  tags = {
    Name = var.instance_name
  }
}