resource "google_storage_bucket" "airflow" {
  name          = var.bucket_name
  location      = var.location
  force_destroy = true
}
root@airflow-20250404-051126:~/airflow-infra-terraform/Airflow-infra/modules/gcs_bucket# cat outputs.tf 
output "bucket_url" {
  value = google_storage_bucket.airflow.url
}
output "bucket_name" {
  value = google_storage_bucket.airflow.name
}