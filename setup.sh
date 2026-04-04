#!/usr/bin/env bash
# =============================================================================
# HomeLab — One-Command Setup
# =============================================================================
#
# This single script creates the entire HomeLab data engineering stack.
# It generates all files, folders, configs, and Dockerfiles, then builds
# and starts everything.
#
# USAGE:
#   git clone https://github.com/yourname/HomeLab.git
#   cd HomeLab
#   make up
#
# That's it. One file. One command.
# =============================================================================
set -euo pipefail

# ---- Colors ----------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

echo -e "${BOLD}"
echo "  ╦ ╦╔═╗╔╦╗╔═╗╦  ╔═╗╔╗ "
echo "  ╠═╣║ ║║║║║╣ ║  ╠═╣╠╩╗"
echo "  ╩ ╩╚═╝╩ ╩╚═╝╩═╝╩ ╩╚═╝"
echo "                     By Maroun"
echo -e "${NC}"
echo "  On-Premise Data Engineering Stack"
echo ""

# ---- Pre-flight checks -----------------------------------------------------
info "Checking prerequisites…"

command -v docker >/dev/null 2>&1 || fail "Docker is not installed. Install it from https://docs.docker.com/get-docker/"

if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  fail "Docker Compose is not installed. Install it from https://docs.docker.com/compose/install/"
fi
ok "Docker & Compose detected (${COMPOSE})"

docker info >/dev/null 2>&1 || fail "Docker daemon is not running. Start Docker Desktop or run 'sudo systemctl start docker'."
ok "Docker daemon is running"

# ---- Create directory structure ---------------------------------------------
info "Creating directory structure…"

DIRS=(
  dagster_home
  dagster_pipelines
  init-db
  notebooks
  seaweedfs_data/master
  seaweedfs_data/volume
  seaweedfs_data/filer
  dbt_project/models/example
  dbt_project/seeds
  dbt_project/tests
  dbt_project/macros
  dbt_project/snapshots
  dbt_project/analyses
  dbt_profiles
  trino_catalogs
)

for d in "${DIRS[@]}"; do
  mkdir -p "$d"
done
ok "All directories created"

# =============================================================================
# GENERATE ALL CONFIG FILES
# =============================================================================
info "Generating configuration files…"

# ---- .env -------------------------------------------------------------------
if [ ! -f ".env" ]; then
cat > .env << 'ENVFILE'
# =============================================================================
# HomeLab — Environment Configuration
# =============================================================================
# All host ports are defined here so you can shift them if another Docker stack
# is already using a port. Just change the LEFT side (host port).
# =============================================================================

# -------------------------
# Network
# -------------------------
NETWORK_NAME=homelab_net

# -------------------------
# Ports — Host Mappings
# -------------------------
# Everything lives in the 10000-10099 range so it won't clash with any
# standard service or other Docker stack. Change any value you like —
# only the host (left) side matters; container-internal ports never change.
#
#   .env variable          → host:container    Service
#   ─────────────────────────────────────────────────────

# --- Core ---
POSTGRES_PORT=10001        # → 10001:5432      PostgreSQL
DAGSTER_PORT=10002         # → 10002:3000      Dagster UI
SUPERSET_PORT=10003        # → 10003:8088      Superset
KESTRA_PORT=10004          # → 10004:8080      Kestra
NIFI_PORT=10005            # → 10005:8443      NiFi (HTTPS)
DREMIO_PORT=10006          # → 10006:9047      Dremio UI
DREMIO_ODBC_PORT=10007     # → 10007:31010     Dremio ODBC/JDBC

# --- Spark ---
SPARK_MASTER_PORT=10010    # → 10010:7077      Spark master
SPARK_UI_PORT=10011        # → 10011:8080      Spark master UI
SPARK_WORKER_UI_PORT=10012 # → 10012:8081      Spark worker UI
SPARK_NOTEBOOK_PORT=10013  # → 10013:8888      Jupyter Lab
SPARK_JOB_UI_PORT=10014    # → 10014:4040      Spark job UI

# --- MinIO ---
MINIO_API_PORT=10020       # → 10020:9000      MinIO S3 API
MINIO_CONSOLE_PORT=10021   # → 10021:9001      MinIO Console

# --- SeaweedFS ---
SEAWEED_MASTER_PORT=10030  # → 10030:9333      SeaweedFS master
SEAWEED_VOLUME_PORT=10031  # → 10031:8400      SeaweedFS volume
SEAWEED_FILER_PORT=10032   # → 10032:8500      SeaweedFS filer
SEAWEED_S3_PORT=10033      # → 10033:8333      SeaweedFS S3

# --- Nessie ---
NESSIE_MINIO_PORT=10040    # → 10040:19120     Nessie (MinIO catalog)
NESSIE_SWFS_PORT=10041     # → 10041:19120     Nessie (SeaweedFS catalog)

# --- Trino ---
TRINO_PORT=10050           # → 10050:8080      Trino UI + JDBC

# -------------------------
# Postgres (shared credentials)
# -------------------------
POSTGRES_USER=myuser
POSTGRES_PASSWORD=mypassword

# -------------------------
# Databases — each service gets its own isolated database
# -------------------------
POSTGRES_DB=postgres
KESTRA_DB=kestradb
NESSIE_MINIO_DB=nessieminiodb
NESSIE_SWFS_DB=nessieswfsdb
DAGSTER_DB=dagsterdb
SUPERSET_DB=supersetdb
TRINO_DB=trinodb

# -------------------------
# S3 Credentials (shared across MinIO & SeaweedFS)
# -------------------------
S3_ACCESS_KEY=admin_key
S3_SECRET_KEY=admin_secret
S3_REGION=us-east-1

# -------------------------
# MinIO
# -------------------------
MINIO_ROOT_USER=admin_key
MINIO_ROOT_PASSWORD=admin_secret

# -------------------------
# NiFi
# -------------------------
NIFI_USERNAME=admin
NIFI_PASSWORD=admin_nifi_123

# -------------------------
# Spark + Jupyter Lab
# -------------------------
JUPYTER_TOKEN=mytoken123

# -------------------------
# Superset
# -------------------------
SUPERSET_SECRET_KEY=change_me_in_production
SUPERSET_ADMIN_USER=admin
SUPERSET_ADMIN_PASSWORD=admin
SUPERSET_ADMIN_FIRSTNAME=admin
SUPERSET_ADMIN_LASTNAME=admin
SUPERSET_ADMIN_EMAIL=admin@test.com

# -------------------------
# Dremio
# First-run wizard sets creds in the browser.
# -------------------------

# -------------------------
# Kestra
# First-run wizard sets creds in the browser.
# -------------------------
ENVFILE
ok "Created .env"
else
  ok ".env already exists — skipping (won't overwrite your changes)"
fi

# ---- docker-compose.yaml ---------------------------------------------------
cat > docker-compose.yaml << 'COMPOSEFILE'
version: "3.9"

services:

  # -------------------------
  # POSTGRES
  # -------------------------
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    ports:
      - "${POSTGRES_PORT}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-db:/docker-entrypoint-initdb.d
    networks:
      - homelab_net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 5s
      timeout: 5s
      retries: 10

  # -------------------------
  # MINIO (STABLE S3)
  # -------------------------
  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    ports:
      - "${MINIO_API_PORT}:9000"
      - "${MINIO_CONSOLE_PORT}:9001"
    volumes:
      - minio_data:/data
    networks:
      - homelab_net

  # -------------------------
  # NESSIE (x2)
  # -------------------------
  nessie-minio:
    image: projectnessie/nessie:latest
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - nessie.version.store.type=JDBC
      - quarkus.datasource.jdbc.url=jdbc:postgresql://postgres:5432/${NESSIE_MINIO_DB}
      - quarkus.datasource.username=${POSTGRES_USER}
      - quarkus.datasource.password=${POSTGRES_PASSWORD}
    ports:
      - "${NESSIE_MINIO_PORT}:19120"
    networks:
      - homelab_net

  nessie-swfs:
    image: projectnessie/nessie:latest
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - nessie.version.store.type=JDBC
      - quarkus.datasource.jdbc.url=jdbc:postgresql://postgres:5432/${NESSIE_SWFS_DB}
      - quarkus.datasource.username=${POSTGRES_USER}
      - quarkus.datasource.password=${POSTGRES_PASSWORD}
    ports:
      - "${NESSIE_SWFS_PORT}:19120"
    networks:
      - homelab_net

  # -------------------------
  # SEAWEEDFS
  # -------------------------
  seaweedfs-master:
    image: chrislusf/seaweedfs:4.07
    command: master -ip=seaweedfs-master -port=9333 -mdir=/data/master
    ports:
      - "${SEAWEED_MASTER_PORT}:9333"
    volumes:
      - ./seaweedfs_data/master:/data/master
    networks:
      - homelab_net

  seaweedfs-volume:
    image: chrislusf/seaweedfs:4.07
    command: volume -mserver=seaweedfs-master:9333 -ip=seaweedfs-volume -port=8400 -dir=/data/volume
    ports:
      - "${SEAWEED_VOLUME_PORT}:8400"
    volumes:
      - ./seaweedfs_data/volume:/data/volume
    depends_on:
      - seaweedfs-master
    networks:
      - homelab_net

  seaweedfs-filer:
    image: chrislusf/seaweedfs:4.07
    command: filer -master=seaweedfs-master:9333 -ip=seaweedfs-filer -port=8500
    ports:
      - "${SEAWEED_FILER_PORT}:8500"
    volumes:
      - ./seaweedfs_data/filer:/data/filer
    depends_on:
      - seaweedfs-master
      - seaweedfs-volume
    networks:
      - homelab_net

  seaweedfs-s3:
    image: chrislusf/seaweedfs:4.07
    ports:
      - "${SEAWEED_S3_PORT}:8333"
    entrypoint: >
      sh -c 'mkdir -p /etc/seaweedfs &&
      printf "{\"identities\":[{\"name\":\"admin\",\"credentials\":[{\"accessKey\":\"${S3_ACCESS_KEY}\",\"secretKey\":\"${S3_SECRET_KEY}\"}],\"actions\":[\"Admin\",\"Read\",\"Write\",\"List\",\"Tagging\"]}]}" > /etc/seaweedfs/s3.json &&
      /entrypoint.sh s3 -filer=seaweedfs-filer:8500 -ip.bind=0.0.0.0 -port=8333 -config=/etc/seaweedfs/s3.json'
    depends_on:
      - seaweedfs-filer
    networks:
      - homelab_net

  # -------------------------
  # SPARK (with Jupyter)
  # -------------------------
  spark:
    platform: linux/x86_64
    image: alexmerced/spark35notebook:latest
    hostname: spark
    ports:
      - "${SPARK_UI_PORT}:8080"
      - "${SPARK_WORKER_UI_PORT}:8081"
      - "${SPARK_MASTER_PORT}:7077"
      - "${SPARK_NOTEBOOK_PORT}:8888"
      - "${SPARK_JOB_UI_PORT}:4040"
    environment:
      AWS_REGION: ${S3_REGION}
      AWS_ACCESS_KEY_ID: ${S3_ACCESS_KEY}
      AWS_SECRET_ACCESS_KEY: ${S3_SECRET_KEY}
      JUPYTER_TOKEN: ${JUPYTER_TOKEN}
      SPARK_LOCAL_IP: 0.0.0.0
      SPARK_PUBLIC_DNS: localhost
    volumes:
      - ./notebooks:/home/docker/work
    networks:
      - homelab_net
    command: >
      bash -c "
      /opt/spark/sbin/start-master.sh &&
      /opt/spark/sbin/start-worker.sh spark://spark:7077 &&
      ~/.local/bin/jupyter lab --ip=0.0.0.0 --port=8888 --no-browser
      "

  # -------------------------
  # DREMIO
  # -------------------------
  dremio:
    image: dremio/dremio-oss:latest
    ports:
      - "${DREMIO_PORT}:9047"
      - "${DREMIO_ODBC_PORT}:31010"
    volumes:
      - dremio_data:/opt/dremio/data
    networks:
      - homelab_net

  # -------------------------
  # TRINO
  # -------------------------
  trino:
    image: trinodb/trino:latest
    ports:
      - "${TRINO_PORT}:8080"
    volumes:
      - ./trino_catalogs:/etc/trino/catalog
    depends_on:
      postgres:
        condition: service_healthy
      nessie-minio:
        condition: service_started
      nessie-swfs:
        condition: service_started
      minio:
        condition: service_started
      seaweedfs-s3:
        condition: service_started
    networks:
      - homelab_net

  # -------------------------
  # SUPERSET
  # -------------------------
  superset:
    image: apache/superset:latest
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      SUPERSET_SECRET_KEY: ${SUPERSET_SECRET_KEY}
      DATABASE_URL: postgresql+psycopg2://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${SUPERSET_DB}
    ports:
      - "${SUPERSET_PORT}:8088"
    restart: unless-stopped
    command: >
      /bin/sh -c "
      superset db upgrade &&
      superset fab create-admin --username ${SUPERSET_ADMIN_USER} --firstname ${SUPERSET_ADMIN_FIRSTNAME} --lastname ${SUPERSET_ADMIN_LASTNAME} --email ${SUPERSET_ADMIN_EMAIL} --password ${SUPERSET_ADMIN_PASSWORD} &&
      superset init &&
      superset run -h 0.0.0.0 -p 8088
      "
    deploy:
      resources:
        limits:
          memory: 2g
    networks:
      - homelab_net

  # -------------------------
  # NIFI
  # -------------------------
  nifi:
    image: apache/nifi:latest
    ports:
      - "${NIFI_PORT}:8443"
    environment:
      SINGLE_USER_CREDENTIALS_USERNAME: ${NIFI_USERNAME}
      SINGLE_USER_CREDENTIALS_PASSWORD: ${NIFI_PASSWORD}
    networks:
      - homelab_net

  # -------------------------
  # DAGSTER
  # -------------------------
  dagster-webserver:
    build:
      context: .
      dockerfile: Dockerfile.dagster
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "${DAGSTER_PORT}:3000"
    environment:
      DAGSTER_PG_USER: ${POSTGRES_USER}
      DAGSTER_PG_PASSWORD: ${POSTGRES_PASSWORD}
      DAGSTER_PG_HOST: postgres
      DAGSTER_PG_DB: ${DAGSTER_DB}
      DAGSTER_PG_PORT: "5432"
    volumes:
      - ./dagster_home:/opt/dagster/dagster_home
      - ./dagster_pipelines:/opt/dagster/app
    command: dagster-webserver -h 0.0.0.0 -p 3000
    networks:
      - homelab_net

  dagster-daemon:
    build:
      context: .
      dockerfile: Dockerfile.dagster
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      DAGSTER_PG_USER: ${POSTGRES_USER}
      DAGSTER_PG_PASSWORD: ${POSTGRES_PASSWORD}
      DAGSTER_PG_HOST: postgres
      DAGSTER_PG_DB: ${DAGSTER_DB}
      DAGSTER_PG_PORT: "5432"
    volumes:
      - ./dagster_home:/opt/dagster/dagster_home
      - ./dagster_pipelines:/opt/dagster/app
    command: dagster-daemon run
    networks:
      - homelab_net

  # -------------------------
  # DBT
  # -------------------------
  dbt:
    build:
      context: .
      dockerfile: Dockerfile.dbt
    volumes:
      - ./dbt_project:/usr/app/dbt
      - ./dbt_profiles:/root/.dbt
    environment:
      DBT_PROFILES_DIR: /root/.dbt
      POSTGRES_HOST: postgres
      POSTGRES_PORT: "5432"
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - homelab_net
    entrypoint: ["tail", "-f", "/dev/null"]

  # -------------------------
  # KESTRA
  # -------------------------
  kestra:
    image: kestra/kestra:latest
    command: server standalone
    environment:
      KESTRA_CONFIGURATION: |
        datasources:
          postgres:
            url: jdbc:postgresql://postgres:5432/${KESTRA_DB}
            username: ${POSTGRES_USER}
            password: ${POSTGRES_PASSWORD}
        kestra:
          repository:
            type: postgres
          storage:
            type: s3
            s3:
              endpoint: http://seaweedfs-s3:8333
              accessKey: ${S3_ACCESS_KEY}
              secretKey: ${S3_SECRET_KEY}
              region: ${S3_REGION}
              bucket: kestra
          queue:
            type: postgres
    ports:
      - "${KESTRA_PORT}:8080"
    depends_on:
      postgres:
        condition: service_healthy
      seaweedfs-s3:
        condition: service_started
    networks:
      - homelab_net

volumes:
  postgres_data:
  dremio_data:
  minio_data:

networks:
  homelab_net:
    name: ${NETWORK_NAME}
COMPOSEFILE
ok "Created docker-compose.yaml"

# ---- Dockerfile.dagster -----------------------------------------------------
cat > Dockerfile.dagster << 'DOCKERFILE'
FROM python:3.11-slim

RUN apt-get update && apt-get install -y gcc && rm -rf /var/lib/apt/lists/*

RUN pip install \
    dagster \
    dagster-webserver \
    dagster-postgres \
    dagster-spark \
    dagster-dbt \
    dagster-shell

WORKDIR /opt/dagster/app
ENV DAGSTER_HOME=/opt/dagster/dagster_home
RUN mkdir -p $DAGSTER_HOME
DOCKERFILE
ok "Created Dockerfile.dagster"

# ---- Dockerfile.dbt ---------------------------------------------------------
cat > Dockerfile.dbt << 'DOCKERFILE'
FROM python:3.11-slim

RUN apt-get update && apt-get install -y gcc git && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    dbt-core \
    dbt-postgres

WORKDIR /usr/app/dbt
DOCKERFILE
ok "Created Dockerfile.dbt"

# ---- dagster_home/dagster.yaml ----------------------------------------------
cat > dagster_home/dagster.yaml << 'DAGSTERYAML'
storage:
  postgres:
    postgres_db:
      username:
        env: DAGSTER_PG_USER
      password:
        env: DAGSTER_PG_PASSWORD
      hostname:
        env: DAGSTER_PG_HOST
      db_name:
        env: DAGSTER_PG_DB
      port:
        env: DAGSTER_PG_PORT
DAGSTERYAML
ok "Created dagster_home/dagster.yaml"

# ---- dagster_pipelines/pipeline.py ------------------------------------------
cat > dagster_pipelines/pipeline.py << 'PYFILE'
from dagster import Definitions

# Your pipelines will go here
defs = Definitions()
PYFILE
ok "Created dagster_pipelines/pipeline.py"

# ---- dagster_pipelines/pyproject.toml ---------------------------------------
cat > dagster_pipelines/pyproject.toml << 'TOMLFILE'
[tool.dagster]
module_name = "pipeline"
TOMLFILE
ok "Created dagster_pipelines/pyproject.toml"

# ---- dbt_profiles/profiles.yml ---------------------------------------------
cat > dbt_profiles/profiles.yml << 'DBTPROFILE'
homelab:
  target: dev
  outputs:
    dev:
      type: postgres
      host: "{{ env_var('POSTGRES_HOST') }}"
      port: "{{ env_var('POSTGRES_PORT') | int }}"
      user: "{{ env_var('POSTGRES_USER') }}"
      pass: "{{ env_var('POSTGRES_PASSWORD') }}"
      dbname: "{{ env_var('POSTGRES_DB') }}"
      schema: public
      threads: 4
DBTPROFILE
ok "Created dbt_profiles/profiles.yml"

# ---- dbt_project/dbt_project.yml -------------------------------------------
cat > dbt_project/dbt_project.yml << 'DBTPROJECT'
name: homelab
version: "1.0.0"
config-version: 2

profile: homelab

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

clean-targets:
  - target
  - dbt_packages
DBTPROJECT
ok "Created dbt_project/dbt_project.yml"

# ---- dbt_project/models/example/stg_example.sql ----------------------------
cat > dbt_project/models/example/stg_example.sql << 'SQLFILE'
-- Replace this with your first staging model.
select 1 as id, 'hello homelab' as message
SQLFILE
ok "Created dbt_project/models/example/stg_example.sql"

# ---- init-db/init.sql -------------------------------------------------------
cat > init-db/init.sql << 'INITSQL'
-- =============================================================================
-- HomeLab — PostgreSQL database initialisation
-- Each service gets its own isolated database for clean tracking.
-- =============================================================================
CREATE DATABASE kestradb;       -- Kestra workflow engine
CREATE DATABASE nessieminiodb;  -- Nessie catalog for MinIO
CREATE DATABASE nessieswfsdb;   -- Nessie catalog for SeaweedFS
CREATE DATABASE dagsterdb;      -- Dagster orchestrator
CREATE DATABASE supersetdb;     -- Apache Superset
CREATE DATABASE trinodb;        -- Trino (postgresql catalog workspace)
INITSQL
ok "Created init-db/init.sql"

# =============================================================================
# TRINO CATALOG FILES
# Values are substituted from .env at generation time — Trino .properties
# files do not support runtime environment variable expansion natively.
# If you change credentials in .env, run: make reset && make up
# =============================================================================
info "Generating Trino catalog files…"

# Read values from .env
PG_USER=$(grep    '^POSTGRES_USER='     .env | cut -d= -f2 | tr -d '[:space:]')
PG_PASS=$(grep    '^POSTGRES_PASSWORD=' .env | cut -d= -f2 | tr -d '[:space:]')
TRINO_DB=$(grep   '^TRINO_DB='          .env | cut -d= -f2 | tr -d '[:space:]')
S3_KEY=$(grep     '^S3_ACCESS_KEY='     .env | cut -d= -f2 | tr -d '[:space:]')
S3_SECRET=$(grep  '^S3_SECRET_KEY='     .env | cut -d= -f2 | tr -d '[:space:]')
S3_REGION=$(grep  '^S3_REGION='         .env | cut -d= -f2 | tr -d '[:space:]')

# ---- iceberg_minio_main.properties ------------------------------------------
cat > trino_catalogs/iceberg_minio_main.properties << TRINOCAT
# =============================================================
# Trino catalog : iceberg_minio_main
# Storage       : MinIO (S3-compatible)
# Catalog       : Nessie — MinIO instance
# Branch        : main
# Usage         : SELECT * FROM iceberg_minio_main.schema.table
# =============================================================
connector.name=iceberg
iceberg.catalog.type=nessie
iceberg.nessie.uri=http://nessie-minio:19120/api/v2
iceberg.nessie.default-reference.name=main
iceberg.nessie.authentication.type=NONE
hive.s3.endpoint=http://minio:9000
hive.s3.path-style-access=true
hive.s3.aws-access-key=${S3_KEY}
hive.s3.aws-secret-key=${S3_SECRET}
hive.s3.region=${S3_REGION}
hive.s3.ssl.enabled=false
TRINOCAT
ok "Created trino_catalogs/iceberg_minio_main.properties"

# ---- iceberg_minio_dev.properties -------------------------------------------
cat > trino_catalogs/iceberg_minio_dev.properties << TRINOCAT
# =============================================================
# Trino catalog : iceberg_minio_dev
# Storage       : MinIO (S3-compatible)
# Catalog       : Nessie — MinIO instance
# Branch        : dev
# Usage         : SELECT * FROM iceberg_minio_dev.schema.table
# =============================================================
connector.name=iceberg
iceberg.catalog.type=nessie
iceberg.nessie.uri=http://nessie-minio:19120/api/v2
iceberg.nessie.default-reference.name=dev
iceberg.nessie.authentication.type=NONE
hive.s3.endpoint=http://minio:9000
hive.s3.path-style-access=true
hive.s3.aws-access-key=${S3_KEY}
hive.s3.aws-secret-key=${S3_SECRET}
hive.s3.region=${S3_REGION}
hive.s3.ssl.enabled=false
TRINOCAT
ok "Created trino_catalogs/iceberg_minio_dev.properties"

# ---- iceberg_swfs_main.properties -------------------------------------------
cat > trino_catalogs/iceberg_swfs_main.properties << TRINOCAT
# =============================================================
# Trino catalog : iceberg_swfs_main
# Storage       : SeaweedFS (S3-compatible)
# Catalog       : Nessie — SeaweedFS instance
# Branch        : main
# Usage         : SELECT * FROM iceberg_swfs_main.schema.table
# =============================================================
connector.name=iceberg
iceberg.catalog.type=nessie
iceberg.nessie.uri=http://nessie-swfs:19120/api/v2
iceberg.nessie.default-reference.name=main
iceberg.nessie.authentication.type=NONE
hive.s3.endpoint=http://seaweedfs-s3:8333
hive.s3.path-style-access=true
hive.s3.aws-access-key=${S3_KEY}
hive.s3.aws-secret-key=${S3_SECRET}
hive.s3.region=${S3_REGION}
hive.s3.ssl.enabled=false
TRINOCAT
ok "Created trino_catalogs/iceberg_swfs_main.properties"

# ---- iceberg_swfs_dev.properties --------------------------------------------
cat > trino_catalogs/iceberg_swfs_dev.properties << TRINOCAT
# =============================================================
# Trino catalog : iceberg_swfs_dev
# Storage       : SeaweedFS (S3-compatible)
# Catalog       : Nessie — SeaweedFS instance
# Branch        : dev
# Usage         : SELECT * FROM iceberg_swfs_dev.schema.table
# =============================================================
connector.name=iceberg
iceberg.catalog.type=nessie
iceberg.nessie.uri=http://nessie-swfs:19120/api/v2
iceberg.nessie.default-reference.name=dev
iceberg.nessie.authentication.type=NONE
hive.s3.endpoint=http://seaweedfs-s3:8333
hive.s3.path-style-access=true
hive.s3.aws-access-key=${S3_KEY}
hive.s3.aws-secret-key=${S3_SECRET}
hive.s3.region=${S3_REGION}
hive.s3.ssl.enabled=false
TRINOCAT
ok "Created trino_catalogs/iceberg_swfs_dev.properties"

# ---- postgresql.properties --------------------------------------------------
cat > trino_catalogs/postgresql.properties << TRINOCAT
# =============================================================
# Trino catalog : postgresql
# Database      : ${TRINO_DB} (Trino's dedicated Postgres workspace)
# Usage         : SELECT * FROM postgresql.public.my_table
#                 CREATE TABLE postgresql.public.my_table AS ...
# Note          : This catalog points exclusively to trinodb —
#                 all other service databases are isolated.
# =============================================================
connector.name=postgresql
connection-url=jdbc:postgresql://postgres:5432/${TRINO_DB}
connection-user=${PG_USER}
connection-password=${PG_PASS}
TRINOCAT
ok "Created trino_catalogs/postgresql.properties"

# ---- tpch.properties --------------------------------------------------------
cat > trino_catalogs/tpch.properties << 'TRINOCAT'
# =============================================================
# Trino catalog : tpch
# Built-in benchmark dataset — no storage required
# Useful for testing Trino is healthy and benchmarking queries
#
# Schemas : tiny (fast), sf1, sf10, sf100 (increasing scale)
# Usage   : SELECT * FROM tpch.tiny.orders
#           SELECT * FROM tpch.sf1.lineitem
# =============================================================
connector.name=tpch
TRINOCAT
ok "Created trino_catalogs/tpch.properties"

# ---- .gitkeep files for empty dirs ------------------------------------------
for d in dbt_project/seeds dbt_project/tests dbt_project/macros dbt_project/snapshots dbt_project/analyses notebooks; do
  touch "$d/.gitkeep"
done
ok "Created .gitkeep placeholders"

info "All files generated!"

# =============================================================================
# PORT CONFLICT SCANNER
# =============================================================================
info "Scanning for host-port conflicts…"

CONFLICT=0
while IFS='=' read -r key val; do
  [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
  [[ "$key" != *_PORT ]] && continue
  val="${val%%#*}"
  val="${val//[[:space:]]/}"
  [[ -z "$val" ]] && continue

  if ss -tlnp 2>/dev/null | grep -q ":${val} " || \
     lsof -iTCP:"${val}" -sTCP:LISTEN >/dev/null 2>&1; then
    warn "Port ${val} (${key}) is already in use!"
    CONFLICT=1
  fi
done < .env

if [ "$CONFLICT" -eq 1 ]; then
  echo ""
  warn "One or more ports conflict with services already running on this machine."
  warn "Edit .env to change the conflicting *_PORT values, then re-run this script."
  echo ""
  read -rp "Continue anyway? (y/N): " answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    echo "Exiting. Fix ports in .env and re-run."
    exit 1
  fi
else
  ok "No port conflicts detected"
fi

# =============================================================================
# BUILD & START
# =============================================================================
info "Building custom images (Dagster, DBT)…"
$COMPOSE build 2>&1 | tail -10
ok "Images built"

info "Pulling upstream images (this may take a while on first run)…"
$COMPOSE pull 2>&1 | tail -10
ok "Images pulled"

info "Starting HomeLab…"
$COMPOSE up -d
ok "All containers launched"

# ---- Wait for Postgres ------------------------------------------------------
info "Waiting for PostgreSQL to become healthy…"

PG_USER_CHECK=$(grep '^POSTGRES_USER=' .env | head -1 | cut -d= -f2)
TRIES=0
until $COMPOSE exec -T postgres pg_isready -U "${PG_USER_CHECK}" >/dev/null 2>&1; do
  TRIES=$((TRIES+1))
  if [ "$TRIES" -gt 60 ]; then
    warn "PostgreSQL did not become ready within 60s. Check: $COMPOSE logs postgres"
    break
  fi
  sleep 1
done

if [ "$TRIES" -le 60 ]; then
  ok "PostgreSQL is healthy"
fi

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   HomeLab is running!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo ""

get_port() { grep "^${1}=" .env | head -1 | cut -d= -f2 | sed 's/#.*//' | tr -d '[:space:]'; }

printf "  %-26s %s\n" "Service" "URL"
printf "  %-26s %s\n" "--------------------------" "-----------------------------------"
printf "  %-26s %s\n" "PostgreSQL"              "localhost:$(get_port POSTGRES_PORT)"
printf "  %-26s %s\n" "Dagster"                 "http://localhost:$(get_port DAGSTER_PORT)"
printf "  %-26s %s\n" "Kestra"                  "http://localhost:$(get_port KESTRA_PORT)"
printf "  %-26s %s\n" "Jupyter Lab"             "http://localhost:$(get_port SPARK_NOTEBOOK_PORT)"
printf "  %-26s %s\n" "Spark Master UI"         "http://localhost:$(get_port SPARK_UI_PORT)"
printf "  %-26s %s\n" "Dremio"                  "http://localhost:$(get_port DREMIO_PORT)"
printf "  %-26s %s\n" "Trino"                   "http://localhost:$(get_port TRINO_PORT)"
printf "  %-26s %s\n" "Superset"                "http://localhost:$(get_port SUPERSET_PORT)"
printf "  %-26s %s\n" "NiFi"                    "https://localhost:$(get_port NIFI_PORT)"
printf "  %-26s %s\n" "MinIO Console"           "http://localhost:$(get_port MINIO_CONSOLE_PORT)"
printf "  %-26s %s\n" "MinIO S3 API"            "http://localhost:$(get_port MINIO_API_PORT)"
printf "  %-26s %s\n" "SeaweedFS S3"            "http://localhost:$(get_port SEAWEED_S3_PORT)"
printf "  %-26s %s\n" "SeaweedFS Filer"         "http://localhost:$(get_port SEAWEED_FILER_PORT)"
printf "  %-26s %s\n" "SeaweedFS Master"        "http://localhost:$(get_port SEAWEED_MASTER_PORT)"
printf "  %-26s %s\n" "Nessie (MinIO)"          "http://localhost:$(get_port NESSIE_MINIO_PORT)/api/v2"
printf "  %-26s %s\n" "Nessie (SeaweedFS)"      "http://localhost:$(get_port NESSIE_SWFS_PORT)/api/v2"
echo ""
printf "  %-26s %s\n" "DBT"       "$COMPOSE exec dbt dbt run"
printf "  %-26s %s\n" "Trino CLI" "$COMPOSE exec trino trino"
echo ""
echo -e "  ${YELLOW}Trino catalogs:${NC}"
echo -e "    iceberg_minio_main  — MinIO    + Nessie (main branch)"
echo -e "    iceberg_minio_dev   — MinIO    + Nessie (dev  branch)"
echo -e "    iceberg_swfs_main   — SeaweedFS + Nessie (main branch)"
echo -e "    iceberg_swfs_dev    — SeaweedFS + Nessie (dev  branch)"
echo -e "    postgresql          — Trino workspace in PostgreSQL (trinodb)"
echo -e "    tpch                — built-in benchmark dataset"
echo ""
echo -e "  ${YELLOW}PostgreSQL databases:${NC}"
echo -e "    trinodb      → Trino workspace"
echo -e "    dagsterdb    → Dagster orchestrator"
echo -e "    supersetdb   → Apache Superset"
echo -e "    kestradb     → Kestra workflows"
echo -e "    nessieminiodb  → Nessie catalog (MinIO)"
echo -e "    nessieswfsdb   → Nessie catalog (SeaweedFS)"
echo ""
echo -e "  ${YELLOW}Tip:${NC} Run '$COMPOSE logs -f <service>' to watch logs."
echo -e "  ${YELLOW}Tip:${NC} Run '$COMPOSE ps' to see all container statuses."
echo -e "  ${YELLOW}Tip:${NC} Edit .env to change any port or password, then: make reset && make up"
echo ""
echo -e "  ${CYAN}Files created in:${NC} $(pwd)"
echo ""
