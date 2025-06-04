# Kolla-GC
Script de automatización para el despliegue de GoyaCloud

## COMO USAR:
Primero de todo copiamos el repositorio:
`git clone https://github.com/SoyToManco16/Kolla-GC.git`

Ahora en nuestra VM o servidor hacemos:
`chmod +x Debbug-dir.sh`
`./Debbug-dir.sh`

Este script nos debuggeará los scripts por si contienen carácteres de escape 
mal formados, y a parte le dará permisos de ejecución a todo el directorio.

Luego debemos de acceder a el archivo `Kolla.sh` para cambiar las variables
para el script.

**VARIABLES PARA KOLLA.SH**
**---------------------------------**
##### [!] VARIABLES REDES
INTERNAL_IP="192.168.18.159"
NETWORK_INTERFACE="enp0s3"
INTERNAL_INTERFACE="enp0s8"

##### [!] VARIABLES BASE
BASE_DISTRO="ubuntu"
VIRT_TYPE="qemu"

##### [!] VARIABLES DIRECTORIOS (NO CAMBIAR A MENOS QUE SEPAMOS QUE HACEMOS)
CLOUDS_DIR="/etc/kolla/clouds.yaml" 
KOLLA_GC_DIR=$(pwd)
GCTOOLS_CUSTOM='source /etc/kolla/gc-tools/custom-commands.sh'

---

**Ahora vamos con la configuración de el gc-runonce**
gc-runonce es un script que hemos diseñado basándonos en init-runonce de el propio Kolla-Ansible para desplegar el contenido de la nube (Redes, instancias...).
Debemos de ajustar las variables del principio del script a nuestra manera.
Solo debe de ejecutarse una vez.

**VARIABLES PARA GC-RUNONCE**
**----------------------------------**
##### [!] VARIABLES PARA RED EXTERNA

EXTERNAL_NETWORK_NAME="red_externa" # Nombre de la red externa
EXTERNAL_SUBNET_RANGE="192.168.210.0/24" # Rango para la subnet
EXTERNAL_GATEWAY="192.168.210.1" # Puerta de enlace
POOL_START="192.168.210.150" # Inicio del pool DHCP dentro de la subnet
POOL_END="192.168.210.199" # Final del pool DHCP dentro de la subnet

##### [!] VARIABLES PARA RED INTERNA

INTERNAL_NETWORK_NAME="red_interna_vms" # Nombre de la red interna
INTERNAL_NETWORK_SUBNET_RANGE="10.0.0.0/24" # Rango para la subnet
INTERNAL_NETWORK_GATEWAY="10.0.0.1" # Puerta de enlace para la subnet
INTERNAL_NETWORK_DNS="8.8.8.8" # Servidor DNS para la red interna

##### [!] VARIABLES PARA CUOTA DE PROYECTO

VMS="10" # Número de máquinas que se pueden crear 
CPUS="16" # Número de CPUs para el proyecto
RAM="22000" # Memoria RAM máxima para el proyecto (En mbs, Ej: 8192)
FLOATING_IPS="10" # IPs Flotantes máximas
SECURITY_GROUPS="20" # Grupos de seguridad (Reglas) máximas
KEY_PAIRS="20" # Pares de claves máximos

---
#### CUANDO TODO ESTÉ CONFIGURADO 
`./Kolla.sh` --> Y mucha paciencia, cuando veamos que se está configurando el Watcher (Para subida de imágenes automáticas) debemos de introducir la contraseña para este usuario.


