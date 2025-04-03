#!/bin/bash
set -e

# Configura replicação no postgresql.conf
setup_replication_config() {
  cat >> "$PGDATA/postgresql.conf" <<EOF
# Configurações de replicação
wal_level = logical
max_wal_senders = 10
max_replication_slots = 10
hot_standby = on
hot_standby_feedback = on
wal_log_hints = on
EOF
}

# Configura permissões para replicação no pg_hba.conf
setup_replication_permissions() {
  cat >> "$PGDATA/pg_hba.conf" <<EOF
# Configurações para replicação
host replication ${POSTGRES_REPLICATION_USER} all md5
host replication all all md5
EOF
}

# Cria o usuário de replicação
create_replication_user() {
  su-exec postgres psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE ROLE ${POSTGRES_REPLICATION_USER} WITH REPLICATION LOGIN PASSWORD '${POSTGRES_REPLICATION_PASSWORD}';
EOSQL
}

echo "Configurando replicação PostgreSQL..."
setup_replication_config
setup_replication_permissions

# Cria usuário de replicação apenas se estiver inicializando o banco
if [ -z "$(ls -A "$PGDATA/pg_wal")" ]; then
  # Inicia temporariamente o PostgreSQL para criar o usuário de replicação
  su-exec postgres pg_ctl -D "$PGDATA" -o "-c listen_addresses='localhost'" -w start

  create_replication_user

  # Para o PostgreSQL temporário
  su-exec postgres pg_ctl -D "$PGDATA" -m fast -w stop
fi

echo "Configuração de replicação concluída."