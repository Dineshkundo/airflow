variable "project_id" {
  description = "The GCP project ID where the bucket will be created."
  type        = string
}

variable "bucket_name" {}

variable "location" {
  description = "The location for the GCS bucket"
  type        = string
}