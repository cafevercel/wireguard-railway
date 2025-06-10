FROM linuxserver/wireguard:latest

# Instalar herramientas necesarias (sin qrencode)
RUN apk add --no-cache \
    curl \
    jq \
    iptables \
    iproute2

# Crear script de configuración personalizada
COPY setup-wireguard.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/setup-wireguard.sh

# Variables de entorno por defecto
ENV PUID=1000
ENV PGID=1000
ENV TZ=America/Havana
ENV PEERS=1
ENV PEERDNS=1.1.1.1,8.8.8.8
ENV INTERNAL_SUBNET=10.13.13.0
ENV ALLOWEDIPS=0.0.0.0/0
ENV SERVERPORT=51820

# Exponer puerto UDP
EXPOSE 51820/udp

# Comando de inicio
CMD ["/usr/local/bin/setup-wireguard.sh"]
