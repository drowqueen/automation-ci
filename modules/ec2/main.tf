terraform {
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

# Data block to look up existing SG
data "aws_security_group" "existing_nginx_sg" {
  name   = "nginx-sg-${var.instance_name}"
  filter {
    name   = "group-name"
    values = ["nginx-sg-${var.instance_name}"]
  }
  count = local.sg_exists ? 1 : 0  # Only query if we expect it to exist
}

locals {
  sg_exists = false  # Set to true if you know it exists; we'll create it otherwise
}

# Create SG only if it doesn't exist
resource "aws_security_group" "nginx_sg" {
  count       = local.sg_exists ? 0 : 1
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
  vpc_security_group_ids = [local.sg_exists ? data.aws_security_group.existing_nginx_sg[0].id : aws_security_group.nginx_sg[0].id]
  user_data     = <<-EOF
                  #!/bin/bash
                  set -x  # Enable command tracing
                  echo "Starting user_data script" > /tmp/user_data.log

                  # Update package list
                  apt-get update >> /tmp/user_data.log 2>&1 || { echo "apt-get update failed" >> /tmp/user_data.log; exit 1; }

                  # Install dependencies for both methods
                  apt-get install -y wget git build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev >> /tmp/user_data.log 2>&1 || { echo "Installing build dependencies failed" >> /tmp/user_data.log; exit 1; }

                  # Choose installation method based on variable
                  if [ "${var.install_method}" = "package" ]; then
                    # Install Nginx via apt-get
                    apt-get install -y nginx >> /tmp/user_data.log 2>&1 || { echo "apt-get install nginx failed" >> /tmp/user_data.log; exit 1; }
                    systemctl enable nginx >> /tmp/user_data.log 2>&1
                    systemctl start nginx >> /tmp/user_data.log 2>&1 || { echo "Failed to start nginx" >> /tmp/user_data.log; exit 1; }
                  elif [ "${var.install_method}" = "source" ]; then
                    # Install Nginx from source
                    cd /tmp
                    wget "http://nginx.org/download/nginx-${var.nginx_version}.tar.gz" >> /tmp/user_data.log 2>&1 || { echo "wget nginx source failed" >> /tmp/user_data.log; exit 1; }
                    tar -xzf "nginx-${var.nginx_version}.tar.gz" >> /tmp/user_data.log 2>&1 || { echo "tar extract failed" >> /tmp/user_data.log; exit 1; }
                    cd "nginx-${var.nginx_version}"
                    ./configure --prefix=/usr/local/nginx --with-http_ssl_module --with-pcre >> /tmp/user_data.log 2>&1 || { echo "nginx configure failed" >> /tmp/user_data.log; exit 1; }
                    make >> /tmp/user_data.log 2>&1 || { echo "nginx make failed" >> /tmp/user_data.log; exit 1; }
                    make install >> /tmp/user_data.log 2>&1 || { echo "nginx make install failed" >> /tmp/user_data.log; exit 1; }
                    ln -s /usr/local/nginx/sbin/nginx /usr/local/bin/nginx >> /tmp/user_data.log 2>&1
                    # Start Nginx
                    /usr/local/nginx/sbin/nginx >> /tmp/user_data.log 2>&1 || { echo "Failed to start nginx from source" >> /tmp/user_data.log; exit 1; }
                  else
                    echo "Invalid install_method: ${var.install_method}. Use 'package' or 'source'" >> /tmp/user_data.log
                    exit 1
                  fi

                  # Verify installation
                  if [ -f /usr/sbin/nginx ] || [ -f /usr/local/nginx/sbin/nginx ]; then
                    nginx -v > /tmp/nginx_check.txt 2>&1
                    echo "Nginx installed successfully" >> /tmp/user_data.log
                  else
                    echo "Nginx installation failed" >> /tmp/user_data.log
                    exit 1
                  fi

                  echo "user_data script completed" >> /tmp/user_data.log
                  EOF

  tags = {
    Name = var.instance_name
  }
}