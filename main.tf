terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5"
    }
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
}

module "vpc" {
  source      = "./modules/vpc"
  project_id  = var.project_id
  region      = var.region
  vpc_name    = var.vpc_name
  subnet_name = var.subnet_name
  cidr_block  = var.cidr_block
}

module "firewall" {
  source        = "./modules/firewall"
  vpc_name      = module.vpc.vpc_name
  vpc_self_link = module.vpc.vpc_self_link
}
module "service_account" {
  source       = "./modules/service_account"
  project_id   = var.project_id
  sa_name      = var.account_id
  roles        = var.roles
}

module "sql_instance" {
  source             = "./modules/sql_instance"
  region             = var.region
  db_instance_name   = var.db_instance_name
  db_tier            = var.db_tier
  db_user            = var.db_user
  db_password        = var.db_password
}

module "gcs_bucket" {
  source      = "./modules/gcs_bucket"
  project_id  = var.project_id
  bucket_name = var.bucket_name
  location = var.location

}

module "airflow_vm" {
  source                = "./modules/airflow_vm"
  vm_name               = var.vm_name
  machine_type          = var.machine_type
  zone                  = var.zone
  vm_image              = var.vm_image
  subnet                = module.vpc.subnet_self_link
  service_account_email = module.service_account.email
}