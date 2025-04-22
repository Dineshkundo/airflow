
output "bucket_url" {
  value = google_storage_bucket.airflow.url
}
output "bucket_name" {
  value = google_storage_bucket.airflow.name
}