variable "project_id" {
    description = "The project ID where resources will be created."
    type        = string
}
variable "region" {
    description = "Project Region"
    type        = string

}
variable "vpc_name" {
    description = "VPC_Name"
    type        = string
}
variable "subnet_name" {
    description = "The name of the subnet"
    type        = string
}
variable "cidr_block" {
    description = "The CIDR block for the subnet."
    type        = string


}
variable "account_id" {}


variable "sa_name" {
  description = "Service Account Name"
  type        = string
}

variable "roles" {
  description = "List of IAM roles for the service account"
  type        = list(string)
}

variable "db_tier" {
    description = "sql instance type"
    type        = string

}
variable "db_instance_name"{
    description = "Data base instance name"
    type        = string
}

variable "db_user" {
    description = "Data base user name"
    type        = string

}
variable "db_password" {
    description = "Data base password"
    type        = string

}

variable "bucket_name" {
    description = "Bucket name"
    type        = string

}

variable "location" {}

variable "vm_name" {
    description = "VM instance name"
    type        = string
   
}
variable "machine_type" {
    description = "VM instance machine type"
    type        = string
}
variable "zone" {
    description = "VM instance zone"
    type        = string
}
variable "vm_image" {
    description = "VM instance Image"
    type        = string
}