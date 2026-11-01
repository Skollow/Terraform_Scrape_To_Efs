variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for resources and the value of the Project tag."
  type        = string
  default     = "scrape-to-efs"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. The public and private subnets are carved out of it."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Two AZs in aws_region: the first hosts the public subnet, the second the private subnet."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Provide exactly two availability zones."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the inspection host."
  type        = string
  default     = "t3.micro"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into the EC2 instance, e.g. \"203.0.113.10/32\" (your public IP)."
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0)) && var.allowed_ssh_cidr != "0.0.0.0/0"
    error_message = "allowed_ssh_cidr must be a valid CIDR and must not be 0.0.0.0/0."
  }
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key registered as the EC2 key pair."
  type        = string
  default     = "~/.ssh/tfkey.pub"
}

variable "schedule_expression" {
  description = "EventBridge schedule for the scraper Lambda (rate() or cron())."
  type        = string
  default     = "rate(1 day)"
}

variable "source_url" {
  description = "JSON endpoint the Lambda fetches."
  type        = string
  default     = "https://api.apis.guru/v2/providers.json"
}

variable "python_command" {
  description = "Local Python interpreter used to build the Lambda package (e.g. \"python\" or \"py\" on Windows)."
  type        = string
  default     = "python3"
}
