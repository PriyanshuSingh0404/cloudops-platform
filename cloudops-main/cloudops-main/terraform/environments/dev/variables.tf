# Data

variable "resource_group_name" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "key_vault_name" {
  type = string
}

# Network

## Module network
variable "address_space" {
  type = string
}

variable "address_prefix" {
  type = string
}

## K8s network profile
variable "service_cidr" {
  type = string
}

variable "dns_service_ip" {
  type = string
}

# Tags

variable "project_name" {
  type = string
}

variable "environment" {
  type    = string
  default = "dev"
}
