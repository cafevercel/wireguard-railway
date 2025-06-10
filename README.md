# WireGuard Server para Railway

Servidor WireGuard completamente configurado para desplegar en Railway.

## 🚀 Despliegue Rápido

1. Haz fork de este repositorio
2. Conecta con Railway
3. Configura las variables de entorno
4. ¡Listo!

## ⚙️ Variables de Entorno

| Variable | Descripción | Valor por defecto |
|----------|-------------|-------------------|
| `PEERS` | Número de clientes | `1` |
| `SERVERPORT` | Puerto WireGuard | `51820` |
| `PEERDNS` | Servidores DNS | `1.1.1.1,8.8.8.8` |
| `INTERNAL_SUBNET` | Red interna | `10.13.13.0` |
| `ALLOWEDIPS` | IPs permitidas | `0.0.0.0/0` |
| `TZ` | Zona horaria | `America/Havana` |

## 📱 Obtener Configuración

Las configuraciones de cliente aparecerán en los logs del deployment.
