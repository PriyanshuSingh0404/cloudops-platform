# 

variable "resource_group_name" {
  type = string
}

variable "resource_group_location" {
  type = string
}

# Linux profile

variable "ssh_key" {
  type = string
}

# Node pool

variable "subnet_id" {
  type = string
}

# Network profile

variable "service_cidr" {
  type = string
}

## Should in range service cidr
variable "dns_service_ip" {
  type = string
}

# Tags

variable "environment" {
  type    = string
  default = "dev"
}

variable "project_name" {
  type = string
}


