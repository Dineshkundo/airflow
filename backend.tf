terraform {
  backend "gcs" {
    bucket = "airflow-terraform-state-bucket"
    prefix = "airflow-gcp/state"
  }
}