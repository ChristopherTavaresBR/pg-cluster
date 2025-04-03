FROM alpine:3.18

RUN apk add --no-cache nfs-utils rpcbind bash tini

# Cria o diretório compartilhado e garante permissões
RUN mkdir -p /exports/shared && \
    chown nobody:nobody /exports/shared && \
    chmod 777 /exports/shared

# Configuração segura do NFS (sem no_root_squash em produção!)
RUN echo "/exports/shared *(rw,sync,no_subtree_check,all_squash,anonuid=65534,anongid=65534)" > /etc/exports

EXPOSE 111/tcp 111/udp 2049/tcp 2049/udp 20048/tcp 20048/udp

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["/bin/bash", "-c", "
    set -e;
    echo 'Iniciando rpcbind...';
    rpcbind -f &
    sleep 2;

    echo 'Iniciando NFS...';
    /usr/sbin/rpc.nfsd 4 &
    sleep 2;

    echo 'Iniciando mountd...';
    /usr/sbin/rpc.mountd -f &
    sleep 2;

    echo 'Exportando diretórios...';
    exportfs -arv;

    echo 'Servidor NFS pronto!';
    tail -f /dev/null
"]