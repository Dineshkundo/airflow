#!/bin/bash

set -e

# === CONFIGURABLE ===
AIRFLOW_USER="airflowuser"
AIRFLOW_VERSION="2.9.3"
INSTANCE_CONNECTION_NAME="adq-get-project:europe-west1:airflow-sql-instance"
DB_USER="airflow"
DB_NAME="airflow_db"
DB_PORT=3306
SECRET_NAME="airflow-mysql-password"
AIRFLOW_HOME="/home/${AIRFLOW_USER}/airflow"
PYTHON_VERSION="$(python3 --version | cut -d ' ' -f 2 | cut -d '.' -f 1-2)"
CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"

# --- CREATE USER ---
if ! id -u "${AIRFLOW_USER}" &>/dev/null; then
    useradd -m -s /bin/bash ${AIRFLOW_USER}
    usermod -aG sudo ${AIRFLOW_USER}
else
    echo "User ${AIRFLOW_USER} already exists"
fi

# --- INSTALL SYSTEM PACKAGES ---
echo "🔧 Installing system dependencies..."
sudo apt update && sudo apt install -y \
    wget gcc python3-dev libpq-dev python3-pip unzip curl \
    build-essential zlib1g-dev libncurses-dev libgdbm-dev libnss3-dev \
    libssl-dev libreadline-dev libffi-dev libsqlite3-dev pkg-config \
    mariadb-client libmariadb-dev

# --- REMOVE MYSQLCLIENT DEV IF INSTALLED ---
echo "🔧 Removing conflicting MySQL client libraries (if present)..."
sudo apt-get remove --purge libmysqlclient-dev -y || true

# --- INSTALL CLOUD SQL PROXY ---
echo "📦 Installing Cloud SQL Proxy..."
sudo mkdir -p /opt/cloud_sql_proxy
sudo wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O /opt/cloud_sql_proxy/cloud_sql_proxy
sudo chmod +x /opt/cloud_sql_proxy/cloud_sql_proxy

# --- CREATE SYSTEMD SERVICE FOR CLOUD SQL PROXY ---
echo "🛠️ Creating systemd service for Cloud SQL Proxy..."
sudo tee /etc/systemd/system/cloud-sql-proxy.service > /dev/null <<EOF
[Unit]
Description=Google Cloud SQL Proxy
After=network.target

[Service]
Type=simple
ExecStart=/opt/cloud_sql_proxy/cloud_sql_proxy -instances=${INSTANCE_CONNECTION_NAME}=tcp:${DB_PORT}
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# --- START CLOUD SQL PROXY SERVICE ---
echo "🔄 Enabling and starting Cloud SQL Proxy service..."
sudo systemctl daemon-reload
sudo systemctl enable cloud-sql-proxy
sudo systemctl start cloud-sql-proxy

# --- SETUP VIRTUAL ENVIRONMENT FOR AIRFLOW ---
echo "📦 Creating Python virtual environment for Airflow..."
sudo -u ${AIRFLOW_USER} bash -c "
python3 -m venv ${AIRFLOW_HOME}/venv
source ${AIRFLOW_HOME}/venv/bin/activate
pip install --upgrade pip
pip install 'apache-airflow[gcp,mysql]' --constraint ${CONSTRAINT_URL}
"

# --- FETCH SECRET FROM SECRET MANAGER ---
DB_PASSWORD=$(gcloud secrets versions access latest --secret=${SECRET_NAME})

# --- SET ENVIRONMENT FOR AIRFLOW ---
echo "📜 Configuring Airflow environment variables..."
export AIRFLOW_HOME=${AIRFLOW_HOME}
export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN="mysql+mysqldb://${DB_USER}:${DB_PASSWORD}@127.0.0.1:${DB_PORT}/${DB_NAME}"

# --- SETUP AIRFLOW DIRECTORY ---
echo "📂 Setting up Airflow directory..."
mkdir -p ${AIRFLOW_HOME}
chown -R ${AIRFLOW_USER}:${AIRFLOW_USER} ${AIRFLOW_HOME}

# --- INITIALIZE AIRFLOW DB & ADMIN USER ---
echo "🔧 Initializing Airflow DB and creating Admin user..."
sudo -u ${AIRFLOW_USER} bash -c "
export AIRFLOW_HOME=${AIRFLOW_HOME}
export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN='mysql+mysqldb://${DB_USER}:${DB_PASSWORD}@127.0.0.1:${DB_PORT}/${DB_NAME}'
source ${AIRFLOW_HOME}/venv/bin/activate
airflow db init
airflow users create \
    --username admin \
    --password admin \
    --firstname Admin \
    --lastname User \
    --role Admin \
    --email admin@example.com
"

# --- CREATE SYSTEMD SERVICE: Airflow Webserver ---
echo "🛠️ Creating systemd service for Airflow Webserver..."
cat <<EOF > /etc/systemd/system/airflow-webserver.service
[Unit]
Description=Airflow Webserver
After=network.target cloud-sql-proxy.service

[Service]
Environment=AIRFLOW_HOME=${AIRFLOW_HOME}
Environment=AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=mysql+mysqldb://${DB_USER}:${DB_PASSWORD}@127.0.0.1:${DB_PORT}/${DB_NAME}
ExecStart=${AIRFLOW_HOME}/venv/bin/airflow webserver --port 8080
Restart=always
User=${AIRFLOW_USER}
WorkingDirectory=${AIRFLOW_HOME}

[Install]
WantedBy=multi-user.target
EOF

# --- CREATE SYSTEMD SERVICE: Airflow Scheduler ---
echo "🛠️ Creating systemd service for Airflow Scheduler..."
cat <<EOF > /etc/systemd/system/airflow-scheduler.service
[Unit]
Description=Airflow Scheduler
After=network.target cloud-sql-proxy.service

[Service]
Environment=AIRFLOW_HOME=${AIRFLOW_HOME}
Environment=AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=mysql+mysqldb://${DB_USER}:${DB_PASSWORD}@127.0.0.1:${DB_PORT}/${DB_NAME}
ExecStart=${AIRFLOW_HOME}/venv/bin/airflow scheduler
Restart=always
User=${AIRFLOW_USER}
WorkingDirectory=${AIRFLOW_HOME}

[Install]
WantedBy=multi-user.target
EOF

# --- START AIRFLOW SERVICES ---
echo "🔄 Reloading systemd and starting Airflow services..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable airflow-webserver
sudo systemctl enable airflow-scheduler
sudo systemctl start airflow-webserver
sudo systemctl start airflow-scheduler

echo "✅ Apache Airflow is up and running!"
echo "🌐 Web UI available at http://<YOUR_VM_IP>:8080"
