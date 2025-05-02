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

echo "🧑 Creating or validating user '${AIRFLOW_USER}'..."
if ! id -u "${AIRFLOW_USER}" &>/dev/null; then
    sudo useradd -m -s /bin/bash ${AIRFLOW_USER}
    sudo usermod -aG sudo ${AIRFLOW_USER}
else
    echo "✅ User ${AIRFLOW_USER} already exists"
fi

# --- SYSTEM DEPENDENCIES ---
echo "🔧 Installing system dependencies..."
sudo apt update && sudo apt install -y \
    wget gcc python3-dev libpq-dev python3-pip unzip curl \
    build-essential zlib1g-dev libncurses-dev libgdbm-dev libnss3-dev \
    libssl-dev libreadline-dev libffi-dev libsqlite3-dev pkg-config \
    mariadb-client libmariadb-dev python3-venv

echo "🔧 Removing libmysqlclient-dev if present..."
sudo apt-get remove --purge libmysqlclient-dev -y || true

# --- CLOUD SQL PROXY ---
echo "📦 Installing Cloud SQL Proxy..."
CLOUD_SQL_PROXY_PATH="/opt/cloud_sql_proxy/cloud_sql_proxy"
sudo mkdir -p /opt/cloud_sql_proxy
if pgrep -f "$CLOUD_SQL_PROXY_PATH" > /dev/null; then
    echo "⚠️ Cloud SQL Proxy is currently running. Skipping overwrite."
elif [ ! -f "$CLOUD_SQL_PROXY_PATH" ]; then
    sudo wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O "$CLOUD_SQL_PROXY_PATH"
    sudo chmod +x "$CLOUD_SQL_PROXY_PATH"
    echo "✅ Cloud SQL Proxy installed."
else
    echo "✅ Cloud SQL Proxy binary already exists."
fi

echo "🛠️ Creating systemd service for Cloud SQL Proxy..."
sudo tee /etc/systemd/system/cloud-sql-proxy.service > /dev/null <<EOF
[Unit]
Description=Google Cloud SQL Proxy
After=network.target

[Service]
Type=simple
ExecStart=${CLOUD_SQL_PROXY_PATH} -instances=${INSTANCE_CONNECTION_NAME}=tcp:${DB_PORT}
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

echo "🔄 Enabling and starting Cloud SQL Proxy service..."
sudo systemctl daemon-reload
sudo systemctl enable cloud-sql-proxy
sudo systemctl restart cloud-sql-proxy

# --- SETUP AIRFLOW DIRECTORIES ---
echo "📂 Setting up Airflow directory at ${AIRFLOW_HOME}..."
sudo mkdir -p "${AIRFLOW_HOME}"
sudo chown -R ${AIRFLOW_USER}:${AIRFLOW_USER} "${AIRFLOW_HOME}"

# --- PYTHON VENV + AIRFLOW INSTALL ---
echo "📦 Creating Airflow virtual environment..."
if [ ! -f "${AIRFLOW_HOME}/venv/bin/activate" ]; then
    sudo -u ${AIRFLOW_USER} python3 -m venv "${AIRFLOW_HOME}/venv"
    sudo -u ${AIRFLOW_USER} bash -c "
        source ${AIRFLOW_HOME}/venv/bin/activate
        pip install --upgrade pip
        pip install 'apache-airflow[gcp,mysql]' --constraint ${CONSTRAINT_URL}
    "
else
    echo "✅ Virtual environment already exists."
fi

# --- VERIFY AIRFLOW ---
echo "🔧 Verifying Airflow installation..."
sudo -u ${AIRFLOW_USER} bash -c "
    source ${AIRFLOW_HOME}/venv/bin/activate
    command -v airflow || { echo '❌ Airflow is not found in venv, exiting...'; exit 1; }
"

# --- FETCH SECRET ---
echo "🔐 Retrieving DB password from Secret Manager..."
DB_PASSWORD=$(gcloud secrets versions access latest --secret="${SECRET_NAME}")

# --- INITIALIZE DB + ADMIN USER ---
echo "🔧 Initializing Airflow DB and creating admin user..."
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

# --- SYSTEMD SERVICES ---
echo "🛠️ Creating systemd service for Airflow Webserver..."
sudo tee /etc/systemd/system/airflow-webserver.service > /dev/null <<EOF
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

echo "🛠️ Creating systemd service for Airflow Scheduler..."
sudo tee /etc/systemd/system/airflow-scheduler.service > /dev/null <<EOF
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

echo "🔄 Starting Airflow services..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable airflow-webserver airflow-scheduler
sudo systemctl restart airflow-webserver airflow-scheduler

echo "✅ Apache Airflow is up and running!"
echo "🌐 Access the Web UI at http://<YOUR_VM_IP>:8080"
