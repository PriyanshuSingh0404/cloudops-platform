variable "resource_group_name" {
  type = string
}

variable "resource_group_location" {
  type = string
}

# Network

variable "address_space" {
  type = string
}

variable "address_prefix" {
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
