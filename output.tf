output "airflow_vm_ip" {
  value = module.airflow_vm.vm_ip
}

output "cloudsql_connection_name" {
  value = module.sql_instance.connection_name
}

output "bucket_name" {
  value = module.gcs_bucket.bucket_name
}