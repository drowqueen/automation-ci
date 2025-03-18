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

                  # Update package lists
                  apt-get update >> /tmp/user_data.log 2>&1 || { echo "apt-get update failed" >> /tmp/user_data.log; exit 1; }

                  # Install Nginx based on install_method
                  if [ "${var.install_method}" = "package" ]; then
                    # Add NGINX stable repository for package method
                    apt-get install -y curl gnupg2 ca-certificates lsb-release >> /tmp/user_data.log 2>&1 || { echo "Prerequisites install failed" >> /tmp/user_data.log; exit 1; }
                    echo "deb http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" | tee /etc/apt/sources.list.d/nginx.list >> /tmp/user_data.log 2>&1
                    curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add - >> /tmp/user_data.log 2>&1
                    apt-get update >> /tmp/user_data.log 2>&1 || { echo "apt-get update after adding repo failed" >> /tmp/user_data.log; exit 1; }
                    # Install specific version via package
                    apt-get install -y nginx=${var.nginx_version} >> /tmp/user_data.log 2>&1 || { echo "apt-get install nginx=${var.nginx_version} failed" >> /tmp/user_data.log; exit 1; }
                  elif [ "${var.install_method}" = "source" ]; then
                    # Install build dependencies for source method
                    apt-get install -y build-essential libpcre3-dev zlib1g-dev libssl-dev >> /tmp/user_data.log 2>&1 || { echo "Build dependencies install failed" >> /tmp/user_data.log; exit 1; }
                    # Download and compile NGINX from source
                    cd /tmp
                    wget "http://nginx.org/download/nginx-${var.nginx_version}.tar.gz" >> /tmp/user_data.log 2>&1 || { echo "wget nginx-${var.nginx_version} failed" >> /tmp/user_data.log; exit 1; }
                    tar -zxvf "nginx-${var.nginx_version}.tar.gz" >> /tmp/user_data.log 2>&1
                    cd "nginx-${var.nginx_version}"
                    ./configure --prefix=/usr/local/nginx --with-http_ssl_module --with-http_v2_module --with-stream >> /tmp/user_data.log 2>&1 || { echo "configure failed" >> /tmp/user_data.log; exit 1; }
                    make >> /tmp/user_data.log 2>&1 || { echo "make failed" >> /tmp/user_data.log; exit 1; }
                    make install >> /tmp/user_data.log 2>&1 || { echo "make install failed" >> /tmp/user_data.log; exit 1; }
                    ln -sf /usr/local/nginx/sbin/nginx /usr/local/bin/nginx >> /tmp/user_data.log 2>&1
                  else
                    echo "Invalid install_method: ${var.install_method}" >> /tmp/user_data.log
                    exit 1
                  fi

                  # Verify installation
                  dpkg -l | grep nginx >> /tmp/nginx_check.txt 2>&1 || echo "Nginx not installed (dpkg check)" >> /tmp/nginx_check.txt
                  /usr/local/bin/nginx -v >> /tmp/nginx_check.txt 2>&1 2>/dev/null || /usr/sbin/nginx -v >> /tmp/nginx_check.txt 2>&1 || echo "Nginx version check failed" >> /tmp/nginx_check.txt

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
                  mkdir -p /etc/nginx/sites-enabled >> /tmp/user_data.log 2>&1
                  ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/ >> /tmp/user_data.log 2>&1

                  # Start Nginx (different paths for package vs source)
                  if [ "${var.install_method}" = "package" ]; then
                    systemctl enable nginx >> /tmp/user_data.log 2>&1
                    systemctl restart nginx >> /tmp/user_data.log 2>&1 || { echo "nginx restart failed" >> /tmp/user_data.log; exit 1; }
                  else
                    /usr/local/nginx/sbin/nginx >> /tmp/user_data.log 2>&1 || { echo "nginx start failed" >> /tmp/user_data.log; exit 1; }
                  fi

                  echo "user_data script completed" >> /tmp/user_data.log
                  EOF

  tags = {
    Name = var.instance_name
  }
}
