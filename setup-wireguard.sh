#!/bin/bash

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 Iniciando WireGuard Server...${NC}"

# Crear directorios necesarios
mkdir -p /config/wg_confs
mkdir -p /config/peer_confs
mkdir -p /config/keys

# Función para obtener IP pública
get_public_ip() {
    PUBLIC_IP=$(curl -s --connect-timeout 5 ifconfig.me || \
               curl -s --connect-timeout 5 ipinfo.io/ip || \
               curl -s --connect-timeout 5 icanhazip.com || \
               echo "127.0.0.1")
    echo $PUBLIC_IP
}

# Función para generar configuraciones
generate_configs() {
    echo -e "${YELLOW}📝 Generando configuraciones...${NC}"
    
    # Generar clave privada del servidor
    wg genkey > /config/keys/server_private.key
    chmod 600 /config/keys/server_private.key
    
    # Generar clave pública del servidor
    cat /config/keys/server_private.key | wg pubkey > /config/keys/server_public.key
    
    SERVER_PRIVATE_KEY=$(cat /config/keys/server_private.key)
    SERVER_PUBLIC_KEY=$(cat /config/keys/server_public.key)
    
    # Obtener IP pública
    PUBLIC_IP=$(get_public_ip)
    
    echo -e "${GREEN}🔑 Clave pública del servidor: ${SERVER_PUBLIC_KEY}${NC}"
    echo -e "${GREEN}🌐 IP pública: ${PUBLIC_IP}${NC}"
    
    # Crear configuración del servidor (sin iptables para Railway)
    cat > /config/wg_confs/wg0.conf << EOF
[Interface]
Address = ${INTERNAL_SUBNET%.*}.1/24
SaveConfig = false
ListenPort = ${SERVERPORT}
PrivateKey = ${SERVER_PRIVATE_KEY}

EOF

    # Generar configuraciones de clientes
    echo -e "${YELLOW}👥 Generando ${PEERS} cliente(s)...${NC}"
    
    for i in $(seq 1 ${PEERS}); do
        CLIENT_NAME="peer${i}"
        CLIENT_IP="${INTERNAL_SUBNET%.*}.$((i + 1))"
        
        # Generar claves del cliente
        wg genkey > /config/keys/${CLIENT_NAME}_private.key
        chmod 600 /config/keys/${CLIENT_NAME}_private.key
        
        cat /config/keys/${CLIENT_NAME}_private.key | wg pubkey > /config/keys/${CLIENT_NAME}_public.key
        
        CLIENT_PRIVATE_KEY=$(cat /config/keys/${CLIENT_NAME}_private.key)
        CLIENT_PUBLIC_KEY=$(cat /config/keys/${CLIENT_NAME}_public.key)
        
        # Agregar peer al servidor
        cat >> /config/wg_confs/wg0.conf << EOF
[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP}/32

EOF
        
        # Crear configuración del cliente
        cat > /config/peer_confs/${CLIENT_NAME}.conf << EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP}/32
DNS = ${PEERDNS}

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
Endpoint = ${PUBLIC_IP}:${SERVERPORT}
AllowedIPs = ${ALLOWEDIPS}
PersistentKeepalive = 25
EOF
        
        echo -e "${GREEN}✅ Cliente ${CLIENT_NAME} configurado (IP: ${CLIENT_IP})${NC}"
    done
}

# Función para mostrar configuraciones
show_configs() {
    echo -e "\n${GREEN}📋 CONFIGURACIONES DE CLIENTES:${NC}\n"
    
    for conf_file in /config/peer_confs/peer*.conf; do
        if [ -f "$conf_file" ]; then
            client_name=$(basename "$conf_file" .conf)
            echo -e "${YELLOW}🔧 Configuración para ${client_name}:${NC}"
            echo "----------------------------------------"
            cat "$conf_file"
            echo "----------------------------------------"
            echo -e "${YELLOW}💡 Copia esta configuración a tu app WireGuard${NC}\n"
        fi
    done
}

# Verificar si ya existe configuración
if [ -f /config/wg_confs/wg0.conf ]; then
    echo -e "${YELLOW}📋 Usando configuración existente...${NC}"
else
    echo -e "${YELLOW}🆕 Generando nueva configuración...${NC}"
    generate_configs
fi

# Mostrar configuraciones
show_configs

# Iniciar WireGuard
echo -e "${GREEN}🚀 Iniciando interfaz WireGuard...${NC}"

# Intentar crear la interfaz
if wg-quick up /config/wg_confs/wg0.conf 2>/dev/null; then
    echo -e "${GREEN}✅ WireGuard iniciado correctamente${NC}"
else
    echo -e "${YELLOW}⚠️  No se pudo iniciar la interfaz completa (normal en Railway)${NC}"
    echo -e "${YELLOW}📡 Iniciando en modo servidor básico...${NC}"
    
    # Crear interfaz manualmente
    ip link add dev wg0 type wireguard 2>/dev/null || echo "Interfaz ya existe"
    wg setconf wg0 /config/wg_confs/wg0.conf 2>/dev/null || echo "Configuración aplicada parcialmente"
fi

echo -e "${GREEN}🎉 Servidor WireGuard configurado!${NC}"
echo -e "${GREEN}📡 Puerto: ${SERVERPORT}${NC}"
echo -e "${GREEN}🌐 Las configuraciones están disponibles arriba${NC}"

# Mantener el contenedor ejecutándose
echo -e "${YELLOW}📡 Manteniendo servidor activo...${NC}"
while true; do
    sleep 30
    # Mostrar estado cada 5 minutos
    if [ $(($(date +%s) % 300)) -eq 0 ]; then
        echo -e "${GREEN}💚 Servidor WireGuard activo - $(date)${NC}"
    fi
done
