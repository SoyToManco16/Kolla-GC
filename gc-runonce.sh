#!/bin/bash
source /etc/kolla/admin-openrc.sh

#========================================#
#   VARIABLES PARA GC-RUNONCE
#========================================#

# [!] VARIABLES PARA RED EXTERNA

EXTERNAL_NETWORK_NAME="red-externa" # Nombre de la red externa
EXTERNAL_SUBNET_RANGE="192.168.210.0/24" # Rango para la subnet
EXTERNAL_GATEWAY="192.168.210.1" # Puerta de enlace
POOL_START="192.168.210.150" # Inicio del pool DHCP dentro de la subnet
POOL_END="192.168.210.199" # Final del pool DHCP dentro de la subnet

# [!] VARIABLES PARA RED INTERNA

INTERNAL_NETWORK_NAME="red-interna-vms" # Nombre de la red interna
INTERNAL_NETWORK_SUBNET_RANGE="10.0.0.0/24" # Rango para la subnet
INTERNAL_NETWORK_GATEWAY="10.0.0.1" # Puerta de enlace para la subnet
INTERNAL_NETWORK_DNS="8.8.8.8" # Servidor DNS para la red interna

# [!] VARIABLES PARA CUOTA DE PROYECTO

VMS="10" # Número de máquinas que se pueden crear 
CPUS="16" # Número de CPUs para el proyecto
RAM="22000" # Memoria RAM máxima para el proyecto (En mbs, Ej: 8192)
FLOATING_IPS="10" # IPs Flotantes máximas
SECURITY_GROUPS="20" # Grupos de seguridad (Reglas) máximas
KEY_PAIRS="20" # Pares de claves máximos

#========================================#
#   CREACIÓN DE PROYECTO Y ROLES
#========================================#

openstack project create --domain default --description " GCloud Deployed by Rubén & Miguel " GoyaCloud

openstack user create --domain default --password 'profesorpass' profesor
openstack role add --project GoyaCloud --user profesor admin

openstack user create --domain default --password 'alumnopass' alumno
openstack role add --project GoyaCloud --user alumno member

#========================================#
# SUBIDA DE IMÁGENES DE PRUEBA
#========================================#

wget -q -O ubuntu.img https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
openstack image create "Ubuntu Focal" \
  --file ubuntu.img \
  --disk-format qcow2 \
  --container-format bare \
  --public

#========================================#
# CREACIÓN DE FLAVORS (CUOTAS PARA VMs)
#========================================#

openstack flavor create --id 1 --ram 512   --disk 5   --vcpus 1 mini    
openstack flavor create --id 2 --ram 1024  --disk 10  --vcpus 1 peque     
openstack flavor create --id 3 --ram 2048  --disk 20  --vcpus 1 mediana     
openstack flavor create --id 4 --ram 4096  --disk 40  --vcpus 2 grande   
openstack flavor create --id 5 --ram 4096  --disk 50  --vcpus 4 potenton

#========================================#
# CONFIGURACIÓN DE REDES
#========================================#

echo "===> Creando red interna-vms y router-privado..."

# Crear la red interna
openstack network create red-interna-vms

# Crear la subred asociada, con gateway y DNS
openstack subnet create subred-interna-vms \
  --network $INTERNAL_NETWORK_NAME \
  --subnet-range $INTERNAL_NETWORK_SUBNET_RANGE \
  --gateway $INTERNAL_NETWORK_GATEWAY \
  --dns-nameserver $INTERNAL_NETWORK_DNS  \
  --ip-version 4

# Crear router privado
openstack router create router-privado

# Asignar el router a la red interna (añadir la subred al router)
openstack router add subnet router-privado subred-interna-vms

# Para que Horizon muestre la red interna a otros proyectos, marcar la red como compartida
openstack network set red-interna-vms --share

echo "===> Creando red externa..."
openstack network create red-externa \
  --external \
  --provider-physical-network physnet1 \
  --provider-network-type flat

openstack subnet create red-externa-subnet \
  --network $EXTERNAL_NETWORK_NAME \
  --subnet-range $EXTERNAL_SUBNET_RANGE \
  --gateway $EXTERNAL_GATEWAY \
  --allocation-pool start=$POOL_START,end=$POOL_END \
  --ip-version 4 \
  --no-dhcp

# Conectar router-privado a la red externa
openstack router set router-privado --external-gateway red-externa

#========================================#
# CONFIGURANDO GRUPOS DE SEGURIDAD
#========================================#

echo "===> Configurando reglas de seguridad..."
admin_project_id=$(openstack project list | awk '/ admin / {print $2}')
sec_group_id=$(openstack security group list --project ${admin_project_id} | awk '/ default / {print $2}')

openstack security group rule create --ingress --ethertype IPv4 --protocol icmp ${sec_group_id}
openstack security group rule create --ingress --ethertype IPv4 --protocol tcp --dst-port 22 ${sec_group_id}
openstack security group rule create --ingress --ethertype IPv4 --protocol tcp --dst-port 8000 ${sec_group_id}
openstack security group rule create --ingress --ethertype IPv4 --protocol tcp --dst-port 8080 ${sec_group_id}

#========================================#
# CREANDO CLAVES PRIVADAS
#========================================#

if [ ! -f ~/.ssh/id_ecdsa.pub ]; then
  echo "===> Generando clave SSH..."
  ssh-keygen -t ecdsa -N '' -f ~/.ssh/id_ecdsa
fi

if [ -f ~/.ssh/id_ecdsa.pub ]; then
  echo "===> Subiendo clave pública a Nova..."
  openstack keypair create --public-key ~/.ssh/id_ecdsa.pub mykey
fi

#========================================#
# CREACIÓN DE CUOTAS
#========================================#

openstack quota set \
  --instances $VMS \
  --cores $CPUS \
  --ram $RAM \
  --floating-ips $FLOATING_IPS \
  --secgroups $SECURITY_GROUPS \
  --key-pairs $KEY_PAIRS \
  GoyaCloud

#========================================#
# ÉXITO !!
#========================================#

echo "
#========================================#
  TODO LISTO PARA EMPEZAR A FUNCIONAR !!
#========================================#
"

