resource "google_sql_database_instance" "airflow" {
  name             = var.db_instance_name
  database_version = "POSTGRES_14"
  region           = var.region
  deletion_protection = false
  settings {
    tier = var.db_tier
    ip_configuration {
      authorized_networks {
        value = "0.0.0.0/0"
      }
    }
  }
}

resource "google_sql_user" "airflow" {
  name     = var.db_user
  password = var.db_password
  instance = google_sql_database_instance.airflow.name
}