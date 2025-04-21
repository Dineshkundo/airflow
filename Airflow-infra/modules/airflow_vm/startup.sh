#!/bin/bash
set -e

# Install Docker and Docker Compose
sudo apt-get update -y
sudo apt-get install -y curl ca-certificates gnupg lsb-release
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo apt-get install -y docker-compose

# Create Airflow Docker Compose setup
mkdir -p /opt/airflow/dags /opt/airflow/logs
sudo chown -R 50000:0 /opt/airflow/logs /opt/airflow/dags
sudo chmod -R 775 /opt/airflow/logs /opt/airflow/dags

cat <<EOF | sudo tee /opt/airflow/docker-compose.yaml > /dev/null
version: '3.8'
services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_USER: airflow
      POSTGRES_PASSWORD: airflow
      POSTGRES_DB: airflow
    volumes:
      - postgres-db-volume:/var/lib/postgresql/data

  airflow-init:
    image: apache/airflow:2.9.0
    depends_on:
      - postgres
    environment:
      AIRFLOW__CORE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres/airflow
      AIRFLOW__CORE__EXECUTOR: LocalExecutor
    command: db init

  airflow-webserver:
    image: apache/airflow:2.9.0
    depends_on:
      - postgres
    environment:
      AIRFLOW__CORE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres/airflow
      AIRFLOW__CORE__EXECUTOR: LocalExecutor
      AIRFLOW__CORE__DEFAULT_TIMEZONE: utc
    ports:
      - "8080:8080"
    volumes:
      - ./dags:/opt/airflow/dags
      - ./logs:/opt/airflow/logs
    command: webserver

  airflow-scheduler:
    image: apache/airflow:2.9.0
    depends_on:
      - postgres
    environment:
      AIRFLOW__CORE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres/airflow
      AIRFLOW__CORE__EXECUTOR: LocalExecutor
      AIRFLOW__CORE__DEFAULT_TIMEZONE: utc
    volumes:
      - ./dags:/opt/airflow/dags
      - ./logs:/opt/airflow/logs
    command: scheduler

volumes:
  postgres-db-volume:
EOF

cd /opt/airflow

# Start the containers
sudo docker-compose up -d

# Wait for Postgres to be ready
echo "Waiting for Postgres to become ready..."
until sudo docker exec $(sudo docker ps -qf "name=postgres") pg_isready -U airflow; do
  echo "Postgres not ready yet — retrying in 5 sec..."
  sleep 5
done

# Initialize Airflow DB inside airflow-init container
sudo docker-compose run --rm airflow-init

# Create Airflow admin user
sudo docker-compose run --rm airflow-webserver \
  airflow users create \
  --username admin \
  --firstname Admin \
  --lastname User \
  --role Admin \
  --email admin@example.com \
  --password admin

# Restart services cleanly
sudo docker-compose down
sudo docker-compose up -d

echo "----------------------------------------"
echo "Airflow setup complete!"
echo "Login URL: http://localhost:8080"
echo "Username: admin"
echo "Password: admin"
echo "----------------------------------------"