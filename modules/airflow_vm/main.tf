resource "google_compute_instance" "airflow_vm" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone
  deletion_protection = false

  boot_disk {
    initialize_params {
      image = var.vm_image
    }
  }

  network_interface {
    subnetwork = var.subnet
    access_config {}
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  metadata = {
    #ssh-keys = "your-username:${file("${path.module}/airflow_vm_key.pub")}"
  }

  provisioner "file" {
    source      = "${path.module}/startup.sh"
    destination = "/tmp/startup.sh"

    connection {
      type        = "ssh"
      user        = "your-username"
      private_key = file("${path.module}/airflow_vm_key")
      host        = self.network_interface[0].access_config[0].nat_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/startup.sh",
      "sudo /tmp/startup.sh"
    ]

    connection {
      type        = "ssh"
      user        = "your-username"
      private_key = file("${path.module}/airflow_vm_key")
      host        = self.network_interface[0].access_config[0].nat_ip
    }
  }
}