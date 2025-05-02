# 🚀 Airflow Setup Script for GCP Environment

This script automates the installation and setup of **Apache Airflow** on a Linux VM (Debian/Ubuntu) for use with **Google Cloud SQL** and **Secret Manager**.

---

## 📂 Script Location

```
/home/script.sh
```

---

## ⚠️ Pre-Requisites (Before Running the Script)

Before executing the script, **you must update the following variables** and complete required setup steps:

### 🔧 1. Update Script Variables
Edit the script and set appropriate values for your environment:

```bash
AIRFLOW_USER="airflowuser"
AIRFLOW_VERSION="2.9.3"
INSTANCE_CONNECTION_NAME="your-gcp-project:your-region:your-instance"
DB_USER="airflow"
DB_NAME="airflow_db"
DB_PORT=3306
SECRET_NAME="airflow-mysql-password"
```

### 🔐 2. Create Secret in Google Cloud Secret Manager
Ensure a **Secret** exists in [GCP Secret Manager](https://console.cloud.google.com/security/secret-manager) that stores your MySQL password.

- Secret name must match the `SECRET_NAME` value.
- Store the **raw database password** as the latest version of the secret.

### 🛢️ 3. Cloud SQL Instance Setup
Make sure your **Cloud SQL instance (MySQL)** is:

- Created and running.
- Accessible via the connection name you provide (`INSTANCE_CONNECTION_NAME`).
- Contains a user and database that match the `DB_USER` and `DB_NAME`.

### ☁️ 4. Enable Required GCP APIs
Make sure the following APIs are enabled:

- Secret Manager API
- Cloud SQL Admin API

---

## ✅ How to Execute

```bash
chmod +x script.sh
sudo ./script.sh
```

The script will:

1. Install system dependencies
2. Install and configure the Cloud SQL Proxy
3. Set up a virtual environment for Airflow
4. Retrieve the DB password from GCP Secret Manager
5. Initialize the Airflow database
6. Create an admin user
7. Configure and start Airflow as a systemd service

---

## 🌐 Access Airflow

After setup, access Airflow Web UI via your browser:

```
http://<YOUR_VM_IP>:8080
```

---

## 📝 Notes

- Default admin credentials are:
  - Username: `admin`
  - Password: `admin`
- Change these after login for security.
- Airflow services (`webserver`, `scheduler`) are set up as persistent systemd services.

---

Let me know if you want this as a downloadable file or need a diagram of the system architecture?
