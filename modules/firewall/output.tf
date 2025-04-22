output "ssh_rule_name" {
  value = google_compute_firewall.allow_ssh.name
}

output "airflow_web_rule_name" {
  value = google_compute_firewall.allow_airflow_web.name
}