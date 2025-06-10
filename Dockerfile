FROM alpine:latest

# Instalar WireGuard y herramientas
RUN apk add --no-cache \
    wireguard-tools \
    curl \
    jq \
    iptables \
    iproute2 \
    bash \
    openrc

# Crear usuario wireguard
RUN addgroup -g 1000 wireguard && \
    adduser -D -u 1000 -G wireguard -s /bin/bash wireguard

# Crear directorios
RUN mkdir -p /config /app && \
    chown -R wireguard:wireguard /config /app

# Copiar script
COPY setup-wireguard.sh /app/
RUN chmod +x /app/setup-wireguard.sh && \
    chown wireguard:wireguard /app/setup-wireguard.sh

# Variables de entorno
ENV PEERS=1
ENV PEERDNS=1.1.1.1,8.8.8.8
ENV INTERNAL_SUBNET=10.13.13.0
ENV ALLOWEDIPS=0.0.0.0/0
ENV SERVERPORT=51820

# Exponer puerto
EXPOSE 51820/udp

# Cambiar a usuario wireguard
USER wireguard
WORKDIR /app

# Comando de inicio
CMD ["./setup-wireguard.sh"]
