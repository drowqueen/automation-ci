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
                  set -x  # Enable command tracing
                  echo "Starting user_data script" > /tmp/user_data.log
                  apt-get update >> /tmp/user_data.log 2>&1 || { echo "apt-get update failed" >> /tmp/user_data.log; exit 1; }
                  apt-get install -y ruby ruby-dev build-essential >> /tmp/user_data.log 2>&1 || { echo "apt-get install ruby ruby-dev build-essential failed" >> /tmp/user_data.log; exit 1; }
                  gem install chef -v 17.10.0 --no-document >> /tmp/user_data.log 2>&1 || { echo "gem install chef failed" >> /tmp/user_data.log; exit 1; }
                  # Find chef-solo binary and add to PATH
                  CHEF_SOLO=$(find / -name chef-solo -type f 2>/dev/null | head -n 1)
                  if [ -z "$CHEF_SOLO" ]; then
                    echo "chef-solo not found" >> /tmp/user_data.log
                    exit 1
                  else
                    echo "Found chef-solo at $CHEF_SOLO" >> /tmp/user_data.log
                    export PATH=$PATH:$(dirname "$CHEF_SOLO")
                  fi
                  mkdir -p /opt/chef/cookbooks/nginx_install/recipes >> /tmp/user_data.log 2>&1
                  mkdir -p /opt/chef/cookbooks/nginx_install/templates >> /tmp/user_data.log 2>&1
                  cd /opt/chef
                  echo 'cookbook_path "/opt/chef/cookbooks"' > solo.rb
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/recipes/default.rb"))}' | base64 -d > cookbooks/nginx_install/recipes/default.rb 2>>/tmp/user_data.log || echo "default.rb write failed" >> /tmp/user_data.log
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/recipes/package_install.rb"))}' | base64 -d > cookbooks/nginx_install/recipes/package_install.rb 2>>/tmp/user_data.log || echo "package_install.rb write failed" >> /tmp/user_data.log
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/recipes/source_install.rb"))}' | base64 -d > cookbooks/nginx_install/recipes/source_install.rb 2>>/tmp/user_data.log || echo "source_install.rb write failed" >> /tmp/user_data.log
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/templates/nginx.conf.erb"))}' | base64 -d > cookbooks/nginx_install/templates/nginx.conf.erb 2>>/tmp/user_data.log || echo "nginx.conf.erb write failed" >> /tmp/user_data.log
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/templates/nginx.service.erb"))}' | base64 -d > cookbooks/nginx_install/templates/nginx.service.erb 2>>/tmp/user_data.log || echo "nginx.service.erb write failed" >> /tmp/user_data.log
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/metadata.rb"))}' | base64 -d > cookbooks/nginx_install/metadata.rb 2>>/tmp/user_data.log || echo "metadata.rb write failed" >> /tmp/user_data.log
                  ls -R cookbooks/nginx_install/ > /tmp/cookbook_files.txt 2>>/tmp/user_data.log
                  echo '{ "install_method": "${var.install_method}", "nginx_version": "${var.nginx_version}", "worker_processes": "${var.worker_processes}", "listen_port": "${var.nginx_port}", "server_name": "${var.server_name}" }' > attributes.json 2>>/tmp/user_data.log
                  chef-solo -c solo.rb -j attributes.json -o nginx_install::default -l debug > /tmp/chef_output.txt 2>&1 || { echo "Chef failed" >> /tmp/chef_error.txt; cat /tmp/chef_error.txt >> /tmp/user_data.log; }
                  dpkg -l | grep nginx > /tmp/nginx_check.txt 2>&1 || echo "Nginx not installed" >> /tmp/nginx_check.txt
                  systemctl status nginx > /tmp/nginx_status.txt 2>&1 || true
                  echo "user_data script completed" >> /tmp/user_data.log
                  EOF

  tags = {
    Name = var.instance_name
  }
}