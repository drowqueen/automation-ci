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
                  mkdir -p cookbooks/nginx_install
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/recipes/default.rb"))}' | base64 -d > cookbooks/nginx_install/recipes/default.rb
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/recipes/package_install.rb"))}' | base64 -d > cookbooks/nginx_install/recipes/package_install.rb
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/recipes/source_install.rb"))}' | base64 -d > cookbooks/nginx_install/recipes/source_install.rb
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/templates/nginx.conf.erb"))}' | base64 -d > cookbooks/nginx_install/templates/nginx.conf.erb
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/templates/nginx.service.erb"))}' | base64 -d > cookbooks/nginx_install/templates/nginx.service.erb
                  echo '${base64encode(file("${path.module}/../chef/cookbooks/nginx_install/metadata.rb"))}' | base64 -d > cookbooks/nginx_install/metadata.rb
                  chef-solo -c solo.rb -o nginx_install::default
                  EOF

  tags = {
    Name = var.instance_name
  }
}