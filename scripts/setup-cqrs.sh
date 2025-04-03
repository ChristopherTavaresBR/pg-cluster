#!/bin/bash
set -e

setup_command_node() {
  # Configuração para nós de comando (escrita)
  echo "Configurando nó como Command (escrita)..."
  
  # Atualiza configurações específicas para nós de comando
  cat >> "$PGDATA/postgresql.conf" <<EOF
# Configurações específicas para nós de comando (escrita)
synchronous_commit = on
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB
default_statistics_target = 100
random_page_cost = 1.1
EOF
}

setup_query_node() {
  # Configuração para nós de consulta (leitura)
  echo "Configurando nó como Query (leitura)..."
  
  # Atualiza configurações específicas para nós de consulta
  cat >> "$PGDATA/postgresql.conf" <<EOF
# Configurações específicas para nós de consulta (leitura)
synchronous_commit = off
max_connections = 200
shared_buffers = 512MB
effective_cache_size = 2GB
default_statistics_target = 200
random_page_cost = 1.1
EOF
}

# Configura o banco de dados com base no modo CQRS
if [ "$CQRS_MODE" = "command" ]; then
  setup_command_node
else
  setup_query_node
fi

echo "Configuração CQRS concluída para modo: $CQRS_MODE"