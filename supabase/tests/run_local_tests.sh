#!/usr/bin/env bash
# Ejecuta las migraciones y las pruebas funcionales en un PostgreSQL local
# (no requiere Supabase). Uso: PGHOST=localhost PGUSER=postgres ./run_local_tests.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DB=rsm_test_$$
psql -v ON_ERROR_STOP=1 -q -d postgres -c "create database $DB"
trap 'psql -q -d postgres -c "drop database if exists $DB"' EXIT
psql -v ON_ERROR_STOP=1 -q -d $DB -f tests/supabase_stub.sql
for f in migrations/*.sql; do echo "Aplicando $f"; psql -v ON_ERROR_STOP=1 -q -d $DB -f "$f"; done
psql -v ON_ERROR_STOP=1 -d $DB -f tests/functional_test.sql
echo "✔ Pruebas de base de datos completadas"
