#!/bin/bash
set -e

# Este script verifica se o volume persistente está disponível e configurado corretamente

# Função para verificar se o volume NFS está montado
check_nfs_mounted() {
  echo "Verificando montagem NFS em $NFS_MOUNT_PATH..."
  
  # Verifica se o diretório existe
  if [ ! -d "$NFS_MOUNT_PATH" ]; then
    echo "Diretório de montagem NFS não existe, criando $NFS_MOUNT_PATH"
    mkdir -p "$NFS_MOUNT_PATH"
  fi
  
  # Verifica se o ponto está montado
  if ! mount | grep -q "$NFS_MOUNT_PATH"; then
    echo "AVISO: Volume NFS não parece estar montado em $NFS_MOUNT_PATH"
    echo "Os dados podem não ser persistentes! Verifique a configuração do volume no Kubernetes."
  else
    echo "Volume NFS montado corretamente em $NFS_MOUNT_PATH"
  fi
}

# Função para verificar permissões no volume de dados PostgreSQL
check_postgres_data_permissions() {
  echo "Verificando permissões do volume de dados PostgreSQL em $PGDATA..."
  
  # Verifica se o diretório existe
  if [ ! -d "$PGDATA" ]; then
    echo "Diretório de dados PostgreSQL não existe, criando $PGDATA"
    mkdir -p "$PGDATA"
  fi
  
  # Verifica permissões
  if [ "$(stat -c '%U:%G' "$PGDATA")" != "postgres:postgres" ]; then
    echo "Corrigindo permissões do volume de dados PostgreSQL"
    chown -R postgres:postgres "$PGDATA"
  fi
  
  # Verifica permissões de escrita
  if ! su-exec postgres [ -w "$PGDATA" ]; then
    echo "ERRO: O usuário postgres não tem permissão de escrita em $PGDATA"
    echo "Ajustando permissões para permitir escrita"
    chmod -R 700 "$PGDATA"
    chown -R postgres:postgres "$PGDATA"
  fi
}

# Função para criar estrutura de diretórios para CQRS se necessário
setup_cqrs_directory_structure() {
  echo "Configurando estrutura de diretórios para CQRS..."
  
  # Diretórios para dados compartilhados entre nós de comando e consulta
  if [ "$CQRS_MODE" = "command" ]; then
    # Apenas o nó de comando cria a estrutura inicial
    SHARED_DIR="$NFS_MOUNT_PATH/shared"
    
    if [ ! -d "$SHARED_DIR" ]; then
      echo "Criando estrutura de diretórios compartilhados em $SHARED_DIR"
      mkdir -p "$SHARED_DIR/backups"
      mkdir -p "$SHARED_DIR/walarchive"
      mkdir -p "$SHARED_DIR/config"
      
      # Cria arquivo de marcação para indicar que a estrutura foi inicializada
      touch "$SHARED_DIR/.initialized"
      
      # Ajusta permissões
      chown -R postgres:postgres "$SHARED_DIR"
    fi
  else
    # Nós de consulta esperam que a estrutura já exista
    SHARED_DIR="$NFS_MOUNT_PATH/shared"
    
    # Verifica se a estrutura compartilhada já foi inicializada
    MAX_ATTEMPTS=30
    ATTEMPT=0
    
    while [ ! -f "$SHARED_DIR/.initialized" ] && [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
      echo "Aguardando inicialização da estrutura compartilhada ($((ATTEMPT+1))/$MAX_ATTEMPTS)..."
      sleep 5
      ATTEMPT=$((ATTEMPT+1))
    done
    
    if [ ! -f "$SHARED_DIR/.initialized" ]; then
      echo "AVISO: Estrutura compartilhada não foi inicializada. Isso pode indicar um problema com o nó de comando."
    else
      echo "Estrutura compartilhada encontrada e disponível."
    fi
  fi
}

# Função para criar links simbólicos para arquivos compartilhados se necessário
setup_shared_config_links() {
  SHARED_CONFIG_DIR="$NFS_MOUNT_PATH/shared/config"
  
  # Se estivermos no modo de consulta, podemos querer usar algumas configurações compartilhadas
  if [ "$CQRS_MODE" = "query" ] && [ -d "$SHARED_CONFIG_DIR" ]; then
    echo "Verificando configurações compartilhadas..."
    
    # Lista de arquivos de configuração que podem ser compartilhados
    SHARED_FILES=("recovery.conf" "postgresql.auto.conf")
    
    for FILE in "${SHARED_FILES[@]}"; do
      if [ -f "$SHARED_CONFIG_DIR/$FILE" ] && [ ! -L "$PGDATA/$FILE" ]; then
        echo "Criando link para configuração compartilhada: $FILE"
        ln -sf "$SHARED_CONFIG_DIR/$FILE" "$PGDATA/$FILE"
      fi
    done
  fi
}

# Principal
echo "Iniciando verificação de volumes..."

# Verificar montagem NFS
check_nfs_mounted

# Verificar permissões no volume de dados
check_postgres_data_permissions

# Configurar estrutura de diretórios para CQRS
setup_cqrs_directory_structure

# Configurar links para arquivos compartilhados
setup_shared_config_links

echo "Verificação de volumes concluída."