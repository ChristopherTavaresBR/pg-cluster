#!/bin/bash
set -e

CREDENTIALS_FILE="$PGDATA/credentials.json"

# Função para gerar senha aleatória
generate_random_password() {
  openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16
}

# Verifica se já existem credenciais no volume persistente
if [ ! -f "$CREDENTIALS_FILE" ]; then
  echo "Gerando novas credenciais..."
  
  # Gera novas senhas se não forem especificadas
  if [ "$POSTGRES_PASSWORD" = "postgres" ]; then
    POSTGRES_PASSWORD=$(generate_random_password)
  fi
  
  if [ "$POSTGRES_REPLICATION_PASSWORD" = "replicator_password" ]; then
    POSTGRES_REPLICATION_PASSWORD=$(generate_random_password)
  fi
  
  # Armazena credenciais em arquivo JSON
  cat > "$CREDENTIALS_FILE" <<EOF
{
  "postgres_user": "$POSTGRES_USER",
  "postgres_password": "$POSTGRES_PASSWORD",
  "postgres_db": "$POSTGRES_DB",
  "replication_user": "$POSTGRES_REPLICATION_USER",
  "replication_password": "$POSTGRES_REPLICATION_PASSWORD",
  "created_at": "$(date -Iseconds)"
}
EOF
  
  # Ajusta permissões
  chown postgres:postgres "$CREDENTIALS_FILE"
  chmod 600 "$CREDENTIALS_FILE"
else
  echo "Usando credenciais existentes do volume persistente..."
  # Carrega credenciais do arquivo
  export POSTGRES_USER=$(jq -r '.postgres_user' "$CREDENTIALS_FILE")
  export POSTGRES_PASSWORD=$(jq -r '.postgres_password' "$CREDENTIALS_FILE")
  export POSTGRES_DB=$(jq -r '.postgres_db' "$CREDENTIALS_FILE")
  export POSTGRES_REPLICATION_USER=$(jq -r '.replication_user' "$CREDENTIALS_FILE")
  export POSTGRES_REPLICATION_PASSWORD=$(jq -r '.replication_password' "$CREDENTIALS_FILE")
fi

echo "Credenciais configuradas com sucesso."