FROM alpine:3.19

# Variáveis de ambiente para configuração
ENV POSTGRES_VERSION=17 \
    PGDATA=/var/lib/postgresql/data \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    POSTGRES_DB=postgres \
    POSTGRES_REPLICATION_USER=replicator \
    POSTGRES_REPLICATION_PASSWORD=replicator_password \
    CQRS_MODE=command \
    NFS_MOUNT_PATH=/mnt/nfs

RUN echo 'http://dl-cdn.alpinelinux.org/alpine/edge/main' > /etc/apk/repositories
RUN apk update --allow-untrusted
RUN apk upgrade --allow-untrusted

# Instala PostgreSQL e dependências necessárias
RUN apk add --no-cache \
    postgresql${POSTGRES_VERSION//.} \
    postgresql${POSTGRES_VERSION//.}-client \
    postgresql${POSTGRES_VERSION//.}-contrib \
    nfs-utils \
    bash \
    su-exec \
    tzdata \
    openssl \
    curl \
    jq \
    gettext

# Cria os diretórios necessários
RUN mkdir -p "$PGDATA" && \
    mkdir -p /docker-entrypoint-initdb.d && \
    mkdir -p "$NFS_MOUNT_PATH" && \
    chown -R postgres:postgres "$PGDATA" /docker-entrypoint-initdb.d

# Configuração de scripts de inicialização
COPY scripts/entrypoint.sh /usr/local/bin/
COPY scripts/setup-cqrs.sh /usr/local/bin/
COPY scripts/setup-replication.sh /usr/local/bin/
COPY scripts/check-volume.sh /usr/local/bin/
COPY scripts/generate-credentials.sh /usr/local/bin/
COPY templates/postgresql.conf.template /etc/postgresql/
COPY templates/pg_hba.conf.template /etc/postgresql/

RUN chmod +x /usr/local/bin/entrypoint.sh \
    /usr/local/bin/setup-cqrs.sh \
    /usr/local/bin/setup-replication.sh \
    /usr/local/bin/check-volume.sh \
    /usr/local/bin/generate-credentials.sh

EXPOSE 5432

VOLUME ["$PGDATA"]

ENTRYPOINT ["entrypoint.sh"]

CMD ["postgres"]