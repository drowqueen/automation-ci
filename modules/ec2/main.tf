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
                  set -x
                  echo "Starting user_data script" > /tmp/user_data.log
                  apt-get update >> /tmp/user_data.log 2>&1 || { echo "apt-get update failed" >> /tmp/user_data.log; exit 1; }
                  # Install Nginx using version from terragrunt.hcl
                  apt-get install -y nginx=${var.nginx_version} >> /tmp/user_data.log 2>&1 || { echo "apt-get install nginx=${var.nginx_version} failed" >> /tmp/user_data.log; exit 1; }
                  # Verify installation
                  dpkg -l | grep nginx >> /tmp/nginx_check.txt 2>&1 || echo "Nginx not installed" >> /tmp/nginx_check.txt
                  # Configure Nginx
                  cat <<EOT > /etc/nginx/sites-available/default
                  server {
                      listen ${var.nginx_port};
                      server_name ${var.server_name};
                      location / {
                          root /var/www/html;
                          index index.html index.htm;
                      }
                  }
                  EOT
                  ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/ >> /tmp/user_data.log 2>&1
                  systemctl enable nginx >> /tmp/user_data.log 2>&1
                  systemctl restart nginx >> /tmp/user_data.log 2>&1 || { echo "nginx restart failed" >> /tmp/user_data.log; exit 1; }
                  nginx -v >> /tmp/nginx_check.txt 2>&1
                  echo "user_data script completed" >> /tmp/user_data.log
                  EOF

  tags = {
    Name = var.instance_name
  }
}