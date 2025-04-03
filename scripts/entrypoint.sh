#!/bin/bash
set -e

# Funções
check_volume_mounted() {
  # Verifica se o volume NFS está montado
  if [ ! -d "$PGDATA" ]; then
    echo "Criando diretório de montagem NFS em $PGDATA"
    mkdir -p "$PGDATA"
  fi
}

setup_postgres_config() {
  # Configura o PostgreSQL com base no modo CQRS
  if [ "$CQRS_MODE" = "command" ]; then
    echo "Configurando nó como Command (escrita)"
    export SYNCHRONOUS_COMMIT=on
    export MAX_CONNECTIONS=100
    export SHARED_BUFFERS=256MB
    export EFFECTIVE_CACHE_SIZE=1GB
  else
    echo "Configurando nó como Query (leitura)"
    export SYNCHRONOUS_COMMIT=off
    export MAX_CONNECTIONS=200
    export SHARED_BUFFERS=512MB
    export EFFECTIVE_CACHE_SIZE=2GB
  fi

  # Processa templates de configuração
  envsubst < /etc/postgresql/postgresql.conf.template > "$PGDATA/postgresql.conf"
  envsubst < /etc/postgresql/pg_hba.conf.template > "$PGDATA/pg_hba.conf"
}

initialize_database() {
  # Verifica se o diretório de dados está vazio
  if [ -z "$(ls -A "$PGDATA")" ]; then
    echo "Inicializando banco de dados PostgreSQL..."
    
    # Inicializa o cluster PostgreSQL
    echo "$POSTGRES_PASSWORD" > /tmp/pwfile
    chmod 644 /tmp/pwfile
    chown postgres:postgres /tmp/pwfile

    chown -R postgres:postgres /data/pgdata  # Se o ID do usuário postgres for 999
    chmod -R 700 /data/pgdata 

    whoami
    #su-exec postgres initdb --username="$POSTGRES_USER" --auth=md5 --pwfile=/dev/stdin <<< "$POSTGRES_PASSWORD"
    su-exec postgres initdb --username="$POSTGRES_USER" --pwfile=/tmp/pwfile
    rm -f /tmp/pwfile

    echo "$POSTGRES_PASSWORD"
    
    # Chama script para gerar credenciais se não existirem
    /usr/local/bin/generate-credentials.sh
    
    # Configura a replicação
    /usr/local/bin/setup-replication.sh
    
    # Configura separação CQRS
    /usr/local/bin/setup-cqrs.sh
    
    # Executa scripts de inicialização personalizados
    for f in /docker-entrypoint-initdb.d/*; do
      case "$f" in
        *.sh)     echo "$0: running $f"; . "$f" ;;
        *.sql)    echo "$0: running $f"; su-exec postgres psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$f" ;;
        *.sql.gz) echo "$0: running $f"; gunzip -c "$f" | su-exec postgres psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" ;;
        *)        echo "$0: ignoring $f" ;;
      esac
    done
  else
    echo "Banco de dados já inicializado, verificando configuração..."
    # Atualiza configurações para o modo CQRS atual
    setup_postgres_config
  fi
}

# Verifica volume NFS
#check_volume_mounted

# Verifica se o diretório PGDATA está disponível
if [ ! -d "$PGDATA" ]; then
  mkdir -p "$PGDATA"
  chown -R 70:70 "$PGDATA"
  chmod -R 700 "$PGDATA"
fi

# Inicializa banco de dados
initialize_database

# Inicia o PostgreSQL com os parâmetros configurados
echo "Iniciando PostgreSQL..."
exec su-exec postgres "$@"