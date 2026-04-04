.PHONY: up down destroy uninstall reset rebuild logs status dbt-run dbt-test trino help

help:
	@echo ""
	@echo "  HomeLab — Available Commands"
	@echo ""
	@echo "  make up          Start the full stack (runs setup.sh)"
	@echo "  make down        Stop all containers (data is preserved)"
	@echo "  make destroy     Stop all containers AND delete all data volumes"
	@echo "  make uninstall   Full wipe — volumes + all Docker images"
	@echo "  make reset       Delete all generated files (use after uninstall)"
	@echo "  make rebuild     Rebuild custom images (Dagster + DBT) then restart"
	@echo "  make logs        Tail live logs for all services (Ctrl+C to exit)"
	@echo "  make status      Show running container statuses"
	@echo "  make dbt-run     Run all dbt models"
	@echo "  make dbt-test    Run all dbt tests"
	@echo "  make trino       Open an interactive Trino CLI session"
	@echo ""
	@echo "  Fresh reinstall workflow:"
	@echo "    make uninstall → make reset → make up"
	@echo ""
	@echo "  Trino catalogs:"
	@echo "    iceberg_minio_main   iceberg_minio_dev"
	@echo "    iceberg_swfs_main    iceberg_swfs_dev"
	@echo "    postgresql           tpch"
	@echo ""

up:
	@bash setup.sh

down:
	@docker compose down

destroy:
	@echo "WARNING: This will delete ALL data volumes. There is no undo."
	@read -p "Type YES to confirm: " confirm && [ "$$confirm" = "YES" ] || exit 1
	@docker compose down -v

uninstall:
	@echo "WARNING: This will delete ALL data volumes AND remove all Docker images."
	@echo "Use this for a completely fresh install. There is no undo."
	@read -p "Type YES to confirm: " confirm && [ "$$confirm" = "YES" ] || exit 1
	@docker compose down -v --rmi all
	@echo ""
	@echo "Done. Run 'make reset' then 'make up' to reinstall from scratch."

reset:
	@echo "Removing all generated files and folders..."
	@rm -rf docker-compose.yaml Dockerfile.dagster Dockerfile.dbt
	@rm -rf dagster_home dagster_pipelines dbt_project dbt_profiles
	@rm -rf init-db notebooks seaweedfs_data trino_catalogs .env
	@echo "Done. Run 'make up' to reinstall from scratch."

rebuild:
	@docker compose build --no-cache dagster-webserver dagster-daemon dbt
	@docker compose up -d

logs:
	@docker compose logs -f

status:
	@docker compose ps

dbt-run:
	@docker compose exec dbt dbt run

dbt-test:
	@docker compose exec dbt dbt test

trino:
	@docker compose exec trino trino
