variable "aws_region" {
  description = "AWS region to deploy the instance"
  type        = string
  default     = "eu-west-1"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "nginx-key"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
}

variable "install_method" {
  description = "Method to install NGINX (package or source)"
  type        = string
}

variable "nginx_version" {
  description = "NGINX version to install"
  type        = string
}

variable "worker_processes" {
  description = "Number of NGINX worker processes"
  type        = string
  default     = "auto"
}

variable "nginx_port" {
  description = "Port on which NGINX will listen, used in security group and config"
  type        = string
  default     = "8080"
}

variable "server_name" {
  description = "Server name for NGINX configuration"
  type        = string
}