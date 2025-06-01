#!/bin/bash

#######################################
# VARIABLES PARA EL DESPLIEGUE
#######################################

# Network Vars
INTERNAL_IP="192.168.18.159"
NETWORK_INTERFACE="enp0s3"
INTERNAL_INTERFACE="enp0s8"

# Base Vars
BASE_DISTRO="ubuntu"
VIRT_TYPE="qemu"

# Dirs
CLOUDS_DIR="/etc/kolla/clouds.yaml" 
KOLLA_GC_DIR=$(pwd)

#######################################
# COMIENZO DEL SCRIPT
#######################################

set -e  # Detener el script si algo falla

echo "
####################################
# ACTUALIZANDO SISTEMA
####################################
"
sudo apt update && sudo apt -y upgrade
sudo apt autoremove -y

echo "
####################################
# INSTALANDO DOCKER Y CONFIGURANDO
####################################
"
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable --now docker

echo "
####################################
# CUBRIENDO DEPENCENCIAS
####################################
"
sudo apt install -y git python3-dev libffi-dev gcc libssl-dev pkg-config libdbus-1-dev build-essential cmake libglib2.0-dev mariadb-server python3-venv

echo "
####################################
# CREANDO ENTORNO VIRTUAL
####################################
"
mkdir -p ~/openstack
cd ~/openstack
python3 -m venv .
source bin/activate

echo "
######################################
# INSTALANDO DEPENDENCIAS DEL ENTORNO
######################################
"
pip install --upgrade pip
pip install setuptools==67.6.1
pip install docker dbus-python wheel

echo "
####################################
# CUBRIENDO DEPENDENCIAS DE ANSIBLE
####################################
"
pip install 'ansible-core>=2.16,<2.17.99'
pip install git+https://opendev.org/openstack/kolla-ansible@master

echo "
####################################
# CONFIGURACIONES INICIALES
####################################
"
echo "==> Creando directorio para kolla <=="
sudo mkdir -p /etc/kolla
sudo chown $USER:$USER /etc/kolla

echo "==> Moviendo los archivos de kolla <=="
cp ~/openstack/share/kolla-ansible/ansible/inventory/all-in-one .
cp -r ~/openstack/share/kolla-ansible/etc_examples/kolla/* /etc/kolla/

echo "
####################################
# CUBRIENDO DEPENDENCIAS KOLLA
####################################
"
kolla-ansible install-deps
kolla-genpwd 

echo "
####################################
# CONFIGURANDO GLOBALS
####################################

"
cat <<EOF | sudo tee /etc/kolla/globals.yml
#####################################
# BASE CONFIGURATION
#####################################
kolla_base_distro: "$BASE_DISTRO" 
nova_compute_virt_type: "$VIRT_TYPE" 

#####################################
# NETWORK CONFIGURATION
#####################################
kolla_internal_vip_address: "$INTERNAL_IP" 
network_interface: "$NETWORK_INTERFACE" # Swap at server
neutron_external_interface: "$INTERNAL_INTERFACE" # Swap at server
 
#####################################
# HEALTHCHECKS
#####################################
enable_container_healthchecks: "yes"
default_container_healthcheck_interval: 3600 # Tiempo entre verificaciones
default_container_healthcheck_timeout: 180 # Tiempo antes de que se marque como fallido
default_container_healthcheck_retries: 3 # 3 fallidos, se reinicia
default_container_healthcheck_start_period: 180 # Tiempo para arrancar antes de checkear
EOF

echo "
####################################
# DESPLEGANDO GC-KOLLA
####################################
"
kolla-ansible bootstrap-servers -i ./all-in-one
kolla-ansible prechecks -i ./all-in-one
kolla-ansible deploy -i ./all-in-one

echo "
####################################
# CONFIGURACIÓN POST-DESPLIEGUE
####################################
"
kolla-ansible post-deploy -i ./all-in-one
cp /etc/kolla/admin-openrc.sh ~/openstack/

#######################################
# END OF DEPLOY - GC
#######################################

# Parsear datos para GC-DEPLOYED
USERNAME=$(cat $CLOUDS_DIR | grep username | awk ' NR==1 {print $2}')
PASS=$(cat $CLOUDS_DIR | grep password | awk ' NR==1 {print $2}')

echo "
####################################
# INSTALANDO OPENSTACK CLI
####################################
"
pip install python3-openstackclient -c https://releases.openstack.org/constraints/upper/master

echo "
####################################
# BACKUP DE ARCHIVOS IMPORTANTES
####################################
"
echo "[+] Copia de globals.yml hecha"
cp /etc/kolla/globals.yml ~/openstack/globals.yml.bak.$(date +%F-%T)

echo "[+] Copia de passwords.yml hecha"
cp /etc/kolla/passwords.yml ~/openstack/passwords.yml.bak.$(date +%F-%T)

echo "
####################################
# DESPLEGANDO HERRAMIENTAS GC
####################################
"

echo "==> CARGANDO HERRAMIENTAS DE GC <=="
mkdir -p /etc/kolla/gc-tools

# Permisos
chmod 755 "$KOLLA_GC_DIR/custom-commands.sh"
chmod 755 "$KOLLA_GC_DIR/UI2G.sh"
chmod 755 "$KOLLA_GC_DIR/qcow2-watcher.sh"

# Copiar herramientas a /etc/kolla/tools
cp "$KOLLA_GC_DIR/custom-commands.sh" /etc/kolla/gc-tools/
cp "$KOLLA_GC_DIR/UI2G.sh" /etc/kolla/gc-tools/
cp "$KOLLA_GC_DIR/qcow2-watcher.sh" /etc/kolla/gc-tools/

# Cargar herramientas en bashrc
GCTOOLS_CUSTOM="source /etc/kolla/gc-tools/custom-commands.sh"
if ! grep -q $GCTOOLS_CUSTOM; then 
    echo "$GCTOOLS_CUSTOM" >> ~/.bashrc
fi

echo "
####################################
# CONFIGURANDO WATCHER (IMG2QCOW2)
####################################
"

source "deploy-watcher.sh" # Me va a pedir interacción para la pass :V

echo "==> EJECUTANDO GC-RUNONCE <=="
./gc-runonce.sh

echo "[!] Cargando comandos personalizados para prueba"
source "$GCTOOLS_CUSTOM"


# Pa frontear
echo "
  ____  ____      ____  _____ ____  _     _____   _______ ____  
 / ___|/ ___|    |  _ \| ____|  _ \| |   / _ \ \ / / ____|  _ \ 
| |  _| |   _____| | | |  _| | |_) | |  | | | \ V /|  _| | | | |
| |_| | |__|_____| |_| | |___|  __/| |__| |_| || | | |___| |_| |
 \____|\____|    |____/|_____|_|   |_____\___/ |_| |_____|____/ 
                                        By Rubén & Miguel


Acceder a Horizon --> http://$INTERNAL_IP

Credenciales para inicio de sesión
#========================================#
Usuario --> $USERNAME
Contraseña --> $PASS

Comandos personalizados para GC (Sudo)
#========================================#
Ejecutar --> gccommands

Para subida de imágenes usar cliente SCP
#========================================#
Windows: WinSCP 
Linux: SCP

SCP Credentials
#========================================#
Usuario --> uploader
Pass --> xxxxxxx
Puerto --> 22
IP --> $INTERNAL_INTERFACE
"