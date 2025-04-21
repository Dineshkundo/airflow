variable "project_id" {
  description = "The project ID where VPC will be created."
  type        = string
}

variable "region" {
  description = "The region for the VPC."
  type        = string
}

variable "vpc_name" {
  description = "The name of the VPC."
  type        = string
}

variable "subnet_name" {
  description = "The name of the subnet."
  type        = string
}

variable "cidr_block" {
  description = "The CIDR block for the subnet."
  type        = string
}
