#!/bin/bash
source /etc/kolla/admin-openrc.sh

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

openstack flavor create --id 1 --ram 512   --disk 5   --vcpus 1 mini     # ideal para Alpine, contenedores o funciones muy básicas
openstack flavor create --id 2 --ram 1024  --disk 10  --vcpus 1 peque      # Debian server mínimo
openstack flavor create --id 3 --ram 2048  --disk 20  --vcpus 1 mediana     # Ubuntu Server, servicios pequeños
openstack flavor create --id 4 --ram 4096  --disk 40  --vcpus 2 grande   # webserver, app server

#========================================#
# CONFIGURACIÓN DE REDES
#========================================#

echo "===> Creando red interna-vms y router-privado..."

# Crear la red interna
openstack network create red-interna-vms

# Crear la subred asociada, con gateway y DNS
openstack subnet create subred-interna-vms \
  --network red-interna-vms \
  --subnet-range 10.0.0.0/24 \
  --gateway 10.0.0.1 \
  --dns-nameserver 8.8.8.8 \
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
  --network red-externa \
  --subnet-range 192.168.18.0/24 \
  --gateway 192.168.18.1 \
  --allocation-pool start=192.168.18.150,end=192.168.18.199 \
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
  --instances 10 \
  --cores 16 \
  --ram 16384 \
  --floating-ips 5 \
  --secgroups 10 \
  --key-pairs 20 \
  GoyaCloud

#========================================#
# ÉXITO !!
#========================================#

echo "
#========================================#
  TODO LISTO PARA EMPEZAR A FUNCIONAR !!
#========================================#
"

