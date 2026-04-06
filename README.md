# HomeLab

A portable, single-node data engineering stack that runs entirely in Docker Compose. Clone the repo, run one command, and the entire stack is up — all files, folders, configs, images, and containers are created automatically.

---

## What's Inside

| Service | Purpose | Default URL |
|---|---|---|
| **PostgreSQL 15** | Shared metadata store | `localhost:10001` |
| **MinIO** | S3-compatible object store (stable) | API `localhost:10020`, Console `localhost:10021` |
| **SeaweedFS** (master + volume + filer + S3 gateway) | S3-compatible object store (distributed) | S3 `localhost:10033` |
| **Nessie (MinIO)** | Iceberg catalog for MinIO — branching, tagging, time travel | `localhost:10040` |
| **Nessie (SeaweedFS)** | Iceberg catalog for SeaweedFS — branching, tagging, time travel | `localhost:10041` |
| **Trino** | Distributed SQL query engine — federates across all sources | `localhost:10050` |
| **Dremio** | Query engine + semantic layer — native Nessie branch UI | `localhost:10006` |
| **Spark 3.5 + Jupyter Lab** | Compute & notebooks | Jupyter `localhost:10013`, Spark UI `localhost:10011` |
| **Apache Superset** | Dashboards & visualization | `localhost:10003` |
| **Apache NiFi** | Data ingestion & routing | `https://localhost:10005` |
| **Dagster** (webserver + daemon) | Orchestration (Python-native) | `localhost:10002` |
| **DBT** | SQL transformations | exec into container |
| **Kestra** | Orchestration (YAML-based) | `localhost:10004` |

### PostgreSQL databases — one per service, fully isolated

| Database | Owner |
|---|---|
| `trinodb` | Trino (postgresql catalog workspace) |
| `dagsterdb` | Dagster orchestrator |
| `supersetdb` | Apache Superset |
| `kestradb` | Kestra workflows |
| `nessieminiodb` | Nessie catalog (MinIO) |
| `nessieswfsdb` | Nessie catalog (SeaweedFS) |

---

## Prerequisites

- **Docker Engine** ≥ 20.10 with Docker Compose v2
- **8 GB RAM** minimum (16 GB recommended)
- **20 GB disk** for images on first pull
- **make** — pre-installed on macOS and Linux

Don't have Docker? Get it from [docs.docker.com/get-docker](https://docs.docker.com/get-docker/).

---

## Quick Start

```bash
git clone https://github.com/yourname/HomeLab.git
cd HomeLab
make up
```

That's it. `make up` will:

1. Check that Docker is installed and running
2. Create all folders and sub-folders
3. Generate every config file (`.env`, `docker-compose.yaml`, Dockerfiles, all Trino catalog files, dbt project, init SQL)
4. Scan ports for conflicts with other services on your machine
5. Build custom images (Dagster, DBT)
6. Pull all upstream images
7. Start everything with `docker compose up -d`
8. Wait for Postgres to become healthy
9. Print a full summary table of every service URL, Trino catalogs, and database layout

---

## Managing the Stack

All day-to-day operations go through `make`. Run `make` or `make help` at any time to see available commands.

```bash
make up          # start the full stack
make down        # stop all containers (data is preserved)
make status      # see all container statuses
make logs        # tail live logs for all services (Ctrl+C to exit)
make rebuild     # rebuild custom images (Dagster + DBT) then restart
make trino       # open an interactive Trino CLI session
make dbt-run     # run all dbt models
make dbt-test    # run all dbt tests
```

---

## Fresh Reinstall

Use this when something breaks, or after adding a new service and needing a clean slate:

```bash
make uninstall   # stop everything and remove all Docker images
make reset       # delete all generated files and folders
make up          # reinstall from scratch
```

> `make uninstall` removes containers, volumes, and all downloaded Docker images (~15–20 GB). `make reset` deletes every file that `setup.sh` generated, leaving only the four repo files. After both, `make up` gives you a brand new install identical to cloning the repo fresh.

---

## DBeaver — Connection Reference

DBeaver is the recommended SQL client for this stack. It connects to every service via JDBC and gives you a single UI for querying Trino, PostgreSQL, and Dremio side by side.

---

### Trino

DBeaver ships with a built-in Trino driver — no extra setup needed.

| Field | Value |
|---|---|
| Driver | `Trino` (search for it in New Connection) |
| Host | `localhost` |
| Port | `10050` |
| Database | leave blank |
| Username | `admin` (any string works — no auth in this setup) |
| Password | leave blank |

**Verify connection with:**
```sql
SHOW CATALOGS;
-- should return: iceberg_minio_main, iceberg_minio_dev,
--                iceberg_swfs_main, iceberg_swfs_dev,
--                postgresql, tpch, system
```

---

### PostgreSQL — per database connections

DBeaver ships with a built-in PostgreSQL driver. Create one connection per database for clean separation — each will appear as its own entry in your DBeaver navigator.

**Shared settings for all connections:**

| Field | Value |
|---|---|
| Driver | `PostgreSQL` |
| Host | `localhost` |
| Port | `10001` |
| Username | `myuser` |
| Password | `mypassword` |

**Create a separate connection for each database:**

| Connection name | Database field |
|---|---|
| HomeLab — Trino workspace | `trinodb` |
| HomeLab — Dagster | `dagsterdb` |
| HomeLab — Superset | `supersetdb` |
| HomeLab — Kestra | `kestradb` |
| HomeLab — Nessie (MinIO) | `nessieminiodb` |
| HomeLab — Nessie (SeaweedFS) | `nessieswfsdb` |

> **Tip:** You only need to actively query `trinodb` day-to-day. The others are service metadata databases — useful for debugging but not for regular data work.

---

### Dremio

Dremio OSS (on-prem) uses the **legacy JDBC driver** on port `31010`. The Arrow Flight SQL driver is for Dremio Cloud only and will not work here.

DBeaver bundles a very old version of the Dremio JDBC driver by default. You need to update it before connecting.

**Step 1 — Update the Dremio JDBC driver in DBeaver:**

1. Download the latest Dremio OSS JDBC driver JAR from inside your running container:
   ```bash
   docker compose cp dremio:/opt/dremio/jars/jdbc-driver/. ./dremio-jdbc/
   # the JAR will be in ./dremio-jdbc/
   ```
2. In DBeaver: `Database → Driver Manager → Dremio`
3. Click `Edit → Libraries tab → Clear all → Add File`
4. Select the JAR you copied out in step 1
5. Click OK

**Step 2 — Create the connection:**

| Field | Value |
|---|---|
| Driver | `Dremio` (after updating the JAR above) |
| Host | `localhost` |
| Port | `10007` |
| Username | *(the admin user you set on first login in browser)* |
| Password | *(the admin password you set on first login in browser)* |

**JDBC URL (use this if the form fields don't work):**
```
jdbc:dremio:direct=localhost:10007
```

> **Note:** Dremio credentials are set on first login via the browser at `http://localhost:10006`. You must complete the first-run wizard in the browser before DBeaver can connect.

---

### Quick connection test for each service

Once connected, run these in DBeaver to confirm everything is healthy:

```sql
-- Trino: check all catalogs are loaded
SHOW CATALOGS;

-- Trino: benchmark query (should return instantly)
SELECT count(*) FROM tpch.tiny.orders;

-- Trino: check Nessie connectivity
SHOW SCHEMAS FROM iceberg_minio_dev;

-- PostgreSQL (trinodb): confirm it's empty and ready
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public';

-- Dremio: check Nessie source is connected
SHOW SCHEMAS IN nessie;
```

---

## Object Storage — First Time Setup

After `make up` you need to create one bucket manually before writing any Iceberg tables.

**MinIO — create the `warehouse` bucket:**
1. Go to `http://localhost:10021` (MinIO Console)
2. Login with `admin_key` / `admin_secret`
3. Click **Buckets → Create Bucket**
4. Name it `warehouse`
5. Click **Create**

This is the bucket Trino and Dremio will use as the default warehouse location for all Iceberg tables.

**SeaweedFS — nothing needed.** SeaweedFS auto-creates buckets on first write. The `warehouse` bucket for Iceberg and the `kestra` bucket for Kestra workflows will both be created automatically when first used.

### Why the difference?

MinIO is strict by design — it never creates buckets automatically, which prevents accidental data sprawl in production. SeaweedFS is permissive by design — it prioritises flexibility for operational workloads. This stack uses them accordingly:

| Storage | Purpose | Bucket behaviour |
|---|---|---|
| MinIO | Your data — Iceberg tables, analytics | Manual creation — you control what exists |
| SeaweedFS | Internal tooling — Kestra, operational data | Auto-created on first write |

---

## Trino — Catalogs & Usage

Six catalogs are pre-configured and ready immediately after `make up`.

| Catalog | Storage | Nessie instance | Branch |
|---|---|---|---|
| `iceberg_minio_main` | MinIO | nessie-minio | main |
| `iceberg_minio_dev` | MinIO | nessie-minio | dev |
| `iceberg_swfs_main` | SeaweedFS | nessie-swfs | main |
| `iceberg_swfs_dev` | SeaweedFS | nessie-swfs | dev |
| `postgresql` | PostgreSQL (`trinodb`) | — | — |
| `tpch` | Built-in benchmark | — | — |

### How catalog files are generated

Trino `.properties` files do not support runtime environment variable expansion. `setup.sh` reads your `.env` values at generation time and writes them directly into the catalog files. If you change credentials in `.env`, run `make reset && make up` to regenerate all catalog files with the new values.

### Usage examples

```sql
-- verify Trino is healthy
SELECT * FROM tpch.tiny.orders LIMIT 5;

-- list schemas on the dev branch (MinIO)
SHOW SCHEMAS FROM iceberg_minio_dev;

-- query a table on the dev branch
SELECT * FROM iceberg_minio_dev.analytics.orders LIMIT 10;

-- query the same table on main (production)
SELECT * FROM iceberg_minio_main.analytics.orders LIMIT 10;

-- create a table in Trino's PostgreSQL workspace
CREATE TABLE postgresql.public.my_table AS
SELECT * FROM tpch.tiny.orders;

-- cross-source federation — join MinIO Iceberg with PostgreSQL
SELECT o.*, c.name
FROM iceberg_minio_main.analytics.orders o
JOIN postgresql.public.customers c ON o.customer_id = c.id;
```

---

## Nessie — Iceberg Catalog (Branching & Time Travel)

Two Nessie instances run in the stack — one for MinIO, one for SeaweedFS. Both support full Git-like data versioning.

### Branch strategy

| Branch | Purpose | Trino catalog | Dremio |
|---|---|---|---|
| `main` | Production — always clean | `iceberg_*_main` | ✅ `AT BRANCH main` |
| `dev` | Integration — all DEs merge here | `iceberg_*_dev` | ✅ `AT BRANCH dev` |
| `feature/*` | Individual work — short-lived | use Dremio only | ✅ `AT BRANCH "feature/x"` |

### Dremio syntax (branch management + exploration)

```sql
-- create a namespace/schema on the dev branch
CREATE SCHEMA nessie.analytics AT BRANCH dev

-- query a specific branch
SELECT * FROM nessie.analytics.orders AT BRANCH dev

-- query a tag (frozen snapshot)
SELECT * FROM nessie.analytics.orders AT TAG v1_release

-- time travel by timestamp
SELECT * FROM nessie.analytics.orders AT TIMESTAMP '2024-01-01 00:00:00'

-- create a feature branch
CREATE BRANCH "feature/sales_model" AT BRANCH dev IN nessie

-- merge back to dev
MERGE BRANCH "feature/sales_model" INTO dev IN nessie

-- tag a release
CREATE TAG v1_release AT BRANCH main IN nessie
```

### Trino syntax (pipeline queries against stable branches)

```sql
-- query fixed branch via catalog name
SELECT * FROM iceberg_minio_dev.analytics.orders

-- switch branch for a session
SET SESSION iceberg_minio_dev.nessie_reference = 'feature/sales_model';

-- time travel by timestamp
SELECT * FROM iceberg_minio_main.analytics.orders
FOR TIMESTAMP AS OF TIMESTAMP '2024-01-01 00:00:00'
```

---

## Configuration — Everything Lives in `.env`

There are **zero hardcoded** ports, passwords, usernames, or database names in any file. Every configurable value is a `${VARIABLE}` that pulls from `.env`.

- Changing a password = one edit in `.env`, then `make reset && make up`
- Moving a port = one edit in `.env`, then `make up`
- Fresh config from scratch = `make reset` then `make up`

`.env` is generated on first run and never overwritten — your customisations are always preserved.

### Full variable reference

| Category | Variables |
|---|---|
| **Ports** | `POSTGRES_PORT`, `DAGSTER_PORT`, `SUPERSET_PORT`, `KESTRA_PORT`, `NIFI_PORT`, `DREMIO_PORT`, `DREMIO_ODBC_PORT`, `SPARK_*_PORT`, `MINIO_*_PORT`, `SEAWEED_*_PORT`, `NESSIE_*_PORT`, `TRINO_PORT` |
| **Postgres** | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` |
| **Databases** | `DAGSTER_DB`, `SUPERSET_DB`, `KESTRA_DB`, `NESSIE_MINIO_DB`, `NESSIE_SWFS_DB`, `TRINO_DB` |
| **S3 / Object Storage** | `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_REGION`, `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD` |
| **Superset** | `SUPERSET_SECRET_KEY`, `SUPERSET_ADMIN_USER`, `SUPERSET_ADMIN_PASSWORD`, `SUPERSET_ADMIN_EMAIL` |
| **NiFi** | `NIFI_USERNAME`, `NIFI_PASSWORD` |
| **Jupyter** | `JUPYTER_TOKEN` |
| **Network** | `NETWORK_NAME` |

---

## Port Reference

All ports are in the `10001–10050` range by default.

| Range | Services |
|---|---|
| `10001–10007` | Core: Postgres, Dagster, Superset, Kestra, NiFi, Dremio |
| `10010–10014` | Spark + Jupyter |
| `10020–10021` | MinIO |
| `10030–10033` | SeaweedFS |
| `10040–10041` | Nessie (MinIO + SeaweedFS) |
| `10050` | Trino |

---

## What Gets Created

After running `make up`, your folder will look like this:

```
HomeLab/
├── setup.sh                     ← repo file
├── Makefile                     ← repo file
├── README.md                    ← repo file
├── .gitignore                   ← repo file
│
│   --- everything below is generated by setup.sh ---
│
├── .env                         # all config: ports, credentials, DB names
├── docker-compose.yaml          # single compose file for the entire stack
├── Dockerfile.dagster           # custom image: Dagster + plugins
├── Dockerfile.dbt               # custom image: dbt-core + dbt-postgres
│
├── trino_catalogs/              # Trino catalog property files
│   ├── iceberg_minio_main.properties
│   ├── iceberg_minio_dev.properties
│   ├── iceberg_swfs_main.properties
│   ├── iceberg_swfs_dev.properties
│   ├── postgresql.properties    # → trinodb (Trino's dedicated PG workspace)
│   └── tpch.properties
│
├── dagster_home/
│   └── dagster.yaml
├── dagster_pipelines/
│   ├── pipeline.py
│   └── pyproject.toml
│
├── dbt_project/
│   ├── dbt_project.yml
│   └── models/example/stg_example.sql
├── dbt_profiles/
│   └── profiles.yml
│
├── init-db/
│   └── init.sql                 # creates all 6 Postgres databases on first boot
│
├── notebooks/                   # shared with Spark/Jupyter
└── seaweedfs_data/              # persistent SeaweedFS volumes
    ├── master/
    ├── volume/
    └── filer/
```

---

## Default Credentials

All credentials live in `.env` — nothing is hardcoded anywhere.

| Service | `.env` variable(s) | Default |
|---|---|---|
| PostgreSQL | `POSTGRES_USER` / `POSTGRES_PASSWORD` | `myuser` / `mypassword` |
| NiFi | `NIFI_USERNAME` / `NIFI_PASSWORD` | `admin` / `admin_nifi_123` |
| Superset | `SUPERSET_ADMIN_USER` / `SUPERSET_ADMIN_PASSWORD` | `admin` / `admin` |
| Jupyter Lab | `JUPYTER_TOKEN` | `mytoken123` |
| MinIO | `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` | `admin_key` / `admin_secret` |
| SeaweedFS S3 | `S3_ACCESS_KEY` / `S3_SECRET_KEY` | `admin_key` / `admin_secret` |
| Dremio | *(set on first login in browser)* | — |
| Kestra | *(set on first login in browser)* | — |

> **Security note:** Change all passwords in `.env` before exposing any ports beyond localhost. After changing credentials run `make reset && make up` so Trino catalog files are regenerated with the new values.

---

## Using DBT

```bash
make dbt-run                                             # run all models
make dbt-test                                            # run all tests
docker compose exec dbt dbt run --select stg_example    # run one model
docker compose exec dbt dbt docs generate               # generate docs
```

The `dbt_project/` folder is bind-mounted — edit files locally and they are instantly available inside the container.

---

## Troubleshooting

**"Cannot find docker-compose.yaml"** — make sure you `cd` into the HomeLab folder first.

**Superset fails with DB errors** — `supersetdb` may not exist: `docker compose exec postgres psql -U $POSTGRES_USER -c '\l'`

**Kestra won't start** — depends on both Postgres and SeaweedFS S3. Check `make logs` or `docker compose logs kestra`.

**Port already in use** — `make up` auto-detects this. Change the port in `.env` and re-run.

**Spark OOM** — increase Docker memory (Docker Desktop → Settings → Resources). 16 GB recommended.

**Databases not created** — `init.sql` only runs on the first Postgres boot (empty volume). If you added or renamed databases later, run the fresh reinstall workflow.

**Trino can't connect to Nessie** — Nessie may still be starting. Check `docker compose logs nessie-minio` or `docker compose logs nessie-swfs`.

**Trino fails to start with catalog property errors** — catalog property names changed in Trino 480+. This stack is tested against Trino 480. If you pinned an older version, the `iceberg.nessie-catalog.*` and `s3.*` property names may differ.

**Trino credentials wrong after changing `.env`** — catalog files are generated once and are not updated automatically. Run `make reset && make up` to regenerate them.

**DBeaver can't connect to Dremio** — make sure you completed the first-run wizard in the browser at `http://localhost:10006` first, and that you updated the Dremio JDBC driver JAR as described in the DBeaver section above.

**Something broke after adding a new service:**
```bash
make uninstall
make reset
make up
```

---

## License

MIT — use it, fork it, break it, fix it.
