#!/bin/bash

###################################
# VARIABLES PARA COMANDOS
###################################
CLOUDS_DIR="/etc/kolla/clouds.yaml" 
GCTOOLS_DIR="/etc/kolla/gc-tools"

# COMANDO PARA ACTUALIZAR ESTE MISMO ARCHIVO
function updategccommands {
    source "$GCTOOLS_DIR/update-gccommands.sh"
}

###################################
# COMANDOS PERSONALIZADOS PARA GC
###################################

# COMPROBAR ROOT
function amiroot {
    if [[ "$(id -u)" -ne 0 ]]; then
    echo "[ERROR] Este comando debe de ser ejecutado como sudo"
    fi
} 

# COMANDO PARA CARGAR DIRECTAMENTE EL ENTORNO VIRTUAL DONDE RESIDE OPENSTACK

function gcenv {
    if amiroot; then
        source ~/openstack/bin/activate
    else
        echo "[ERROR] Careces de permisos para realizar esta función"
    fi
}

# COMANDO PARA CARGAR ADMIN-OPENRC 

function gcreds {
    if amiroot; then
        source ~/openstack/admin-openrc.sh 
    else 
        echo "[ERROR] Careces de permisos para realizar esta función"
    fi
}

# COMANDO PARA CARGAR ENTORNO Y CREDENCIALES (SOY VAGO SI, QUE PASA)

function upgc {
    if amiroot; then 
        gcenv
        gcreds
    else 
        echo "[ERROR] Careces de permisos para realizar esta función"
    fi
}

# LLAMAR AL SCRIPT QUE SUBE IMÁGENES DE GLANCE (Interactivo)

function ui2g {
    if amiroot; then 
        source "$GCTOOLS_DIR/UI2G.sh"
    else 
        echo "[ERROR] Careces de permisos para realizar esta función"
    fi
}

# FUNCIÓN PARA VER SI EL WATCHER ESTÁ DESPIERTO (Si no lo despierta, que no es andaluz)

function checkwatcher {
    AWAKE=$(systemctl is-active img2qcow2-watcher)
    if [ "$AWAKE" != "active" ]; then
        echo "[!] Watcher estaba durmiendo, despertando..."
        sudo systemctl start img2qcow2-watcher
    else 
        echo "[:D] Watcher está despierto !!"
    fi
}

# FUNCIÓN PARA COMPROBAR EL LOG DEL WATCHER

function logwatcher {
    cat "/etc/kolla/watcher.log"
}

###################################
# COMANDOS PARA CHECKEAR SERVICIOS
###################################

# FUNCIÓN PARA COMPROBAR KEYSTONE

function checkkeystone {
  if openstack token issue >/dev/null 2>&1; then
    echo "[+] Keystone OK"
  else
    echo "[!] Keystone fallando"
  fi
}

# FUNCIÓN PARA CHECKEAR QUE SERVICIOS ESTÁN INSTALADOS

function checkservices {
    openstack service list
}

# FUNCIÓN PARA COMPROBAR QUE CONTENEDORES ESTÁN SANOS

function checkdockerhealth {
for c in $(docker ps --format '{{.Names}}'); do
  state=$(docker inspect --format='{{.State.Health.Status}}' $c 2>/dev/null || echo "no-healthcheck")
  echo "$c → $state"
done
}

# FUNCIÓN PARA LISTAR TODOS LOS SERVICIOS

function checkall() {
  local mode="$1"
  local report_file

  if [[ "$mode" == "report" ]]; then
    timestamp=$(date +%Y%m%d-%H%M%S)
    report_file="checkall_report_${timestamp}.txt"
    exec > >(tee "$report_file") 2>&1
    echo "Generando reporte en: $report_file"
    echo
  fi

  echo "
#########################################
CHECKEANDO CONTENEDORES KOLLA
#########################################
"
  echo "[!] Contenedores que no aparecen 'healthy' indican falta de healthcheck o fallo"
  docker ps --format 'table {{.Names}}\t{{.Status}}'

  echo "
#########################################
CHECKEANDO ENDPOINTS
#########################################
"
  openstack endpoint list

  echo "
#########################################
CHECKEANDO SERVICIOS DE CÓMPUTO (Nova)
#########################################
"
  openstack compute service list

  echo "
#########################################
CHECKEANDO AGENTES DE NEUTRON
#########################################
"
  openstack network agent list

  echo "
#########################################
CHECKEANDO IMÁGENES EN GLANCE
#########################################
"
  listimages # Nuestro comando

  if [[ -n "$report_file" ]]; then
    echo "[+] Reporte generado :)"
  fi
}

###################################
# ATAJOS PARA OPENSTACK CLI
###################################

# LISTAR PROYECTOS

function listprojects {
    gcenv
    openstack project list
}

# LISTAR ROLES 

function listroles {
    gcenv
    openstack role list
}

# LISTAR USUARIOS

function listusers {
    gcenv
    openstack user list
}

# LISTAR FLAVORS

function listflavors {
    gcenv 
    openstack flavor list
}

# LISTAR IMÁGENES DISPONIBLES

function listimages {
    gcenv
    openstack image list
}

# LISTAR REDES

function listnetworks {
    gcenv 
    openstack network list
}

# LISTAR SUBREDES

function listsubnets {
    gcenv 
    openstack subnet list
}

# LISTAR ROUTERS

function listrouters {
    gcenv
    openstack router list
}

# LISTAR PUERTOS

function listports {
    gcenv
    openstack port list
}

# LISTAR IPS FLOTANTES

function listfloatingip {
    gcenv
    openstack floating ip list
}

# LISTAR INSTANCIAS

function listvms {
    gcenv 
    openstack server list
}

# LISTAR QUOTA

function listquota() {
    if [ -z "$1" ]; then
        openstack quota list --network
        openstack quota list --compute
    else 
        openstack quota list --network "$1"
        openstack quota list --compute "$1"
    fi
}

# MOSTRAR INFORMACIÓN IMPORTANTE DE HORIZON

function horizon {
    USERNAME=$(cat $CLOUDS_DIR | grep username | awk ' NR==1 {print $2}')
    PASS=$(cat $CLOUDS_DIR | grep password | awk ' NR==1 {print $2}')
    URL=$(cat $CLOUDS_DIR | grep auth_url | awk ' NR==1 {print $2}')
    
echo "
 _   _            _                
| | | | ___  _ __(_)_______  _ __  
| |_| |/ _ \| '__| |_  / _ \| '_ \ 
|  _  | (_) | |  | |/ / (_) | | | |
|_| |_|\___/|_|  |_/___\___/|_| |_|

Accede a Horizon --> $URL

CREDENCIALES
------------------------------------
Usuario --> $USERNAME
Contraseña --> $PASS
"
}

###################################
# MOSTRAR COMANDOS DISPONIBLES
###################################

function gccommands() {
    if [ "$1" == "gc" ]; then
        echo "
#############################################################################################
#                              COMANDOS PERSONALIZADOS PARA GC                              #
#############################################################################################

################################################
ACTUALIZAR COMANDOS --> updategccommands #######
################################################

# CARGAR ENTORNO --> gcenv
# CARGAR CREDENCIALES --> gcreds
# CARGAR ENTORNO Y CREDS --> upgc
# LLAMAR SCRIPT INTERACTIVO DE DESCARGA Y SUBIDA DE IMÁGENES LINUX --> ui2g
# COMPROBAR ESTADO DEL WATCHER --> checkwatcher
# COMPROBAR LOG DEL WATCHER --> logwatcher
"
    elif [ "$1" == "keystone" ]; then
        echo "
    #=======================================#
                    KEYSTONE
    #=======================================#
    # COMPROBAR KEYSTONE --> checkkeystone
    # MOSTRAR PROYECTOS --> listprojects
    # MOSTRAR ROLES --> listroles
    # MOSTRAR USUARIOS --> listusers
"
    elif [ "$1" == "img" ]; then
        echo "
    #=======================================#
                    GLANCE
    #=======================================#
    # MOSTRAR FLAVORS --> listflavors
    # MOSTRAR IMÁGENES --> listimages
"
    elif [ "$1" == "red" ]; then
        echo "
    #=======================================#
                    NEUTRON
    #=======================================#
    # MOSTRAR REDES --> listnetworks
    # MOSTRAR SUBREDES --> listsubnets
    # MOSTRAR ROUTERS --> listrouters
    # MOSTRAR PUERTOS --> listports
    # MOSTRAR FLOATING IPS --> listfloatingip
"
    elif [ "$1" == "nova" ]; then
        echo "
    #=======================================#
                    NOVA
    #=======================================#
    # MOSTRAR INSTANCIAS --> listvms
"
    elif [ "$1" == "horizon" ]; then
        echo "
    #=======================================#
                    HORIZON
    #=======================================#
    # MOSTRAR INFO HORIZON --> horizon
"
    elif [ "$1" == "misc" ]; then
        echo "
    #=======================================#
                  MISCELÁNEA
    #=======================================#
    # MOSTRAR CUOTAS --> listquota <proyecto>
    (Sin proyecto, usa el predeterminado)

    # MOSTRAR SERVICIOS DESPLEGADOS --> checkservices
"
    elif [ "$1" == "health" ]; then
        echo "
    #=======================================#
                  HEALTHCHECKS
    #=======================================#
    # COMPROBAR DOCKER --> checkdockerhealth
    # COMPROBAR TODO --> checkall <reporte>
    (si introducimos reporte nos crea un log)
"
    else
        echo "
#############################################################################################
#                              COMANDOS PERSONALIZADOS PARA GC                              #
#############################################################################################

################################################
ACTUALIZAR COMANDOS --> updategccommands #######
################################################

# CARGAR ENTORNO --> gcenv
# CARGAR CREDENCIALES --> gcreds
# CARGAR ENTORNO Y CREDS --> upgc
# LLAMAR SCRIPT INTERACTIVO DE DESCARGA Y SUBIDA DE IMÁGENES LINUX --> ui2g
# COMPROBAR ESTADO DEL WATCHER --> checkwatcher
# COMPROBAR LOG DEL WATCHER --> logwatcher

#############################################################################################
#                                  ATAJOS PARA OPENSTACK CLI                                #
#############################################################################################
         #                         MOSTRAR INFORMACIÓN                           #
         #########################################################################

    #=======================================#           #=======================================#
                    KEYSTONE                                            GLANCE
    #=======================================#           #=======================================#
    # COMPROBAR KEYSTONE --> checkkeystone              # MOSTRAR FLAVORS --> listflavors
    # MOSTRAR PROYECTOS --> listprojects                # MOSTRAR IMÁGENES --> listimages
    # MOSTRAR ROLES --> listroles                       #
    # MOSTRAR USUARIOS --> listusers                    #

    #=======================================#           #=======================================#
                    NEUTRON                                               NOVA
    #=======================================#           #=======================================#
    # MOSTRAR REDES --> listnetworks                    # MOSTRAR INSTANCIAS --> listvms
    # MOSTRAR SUBREDES --> listsubnets
    # MOSTRAR ROUTERS --> listrouters
    # MOSTRAR PUERTOS --> listports
    # MOSTRAR FLOATING IPS --> listfloatingip

    #=======================================#           #=======================================#
                    HORIZON                                            MISCELÁNEA
    #=======================================#           #=======================================#
    # MOSTRAR INFO HORIZON --> horizon                  # MOSTRAR CUOTAS --> listquota <proyecto>
                                                            (Sin proyecto, usa el predeterminado)

                                                        # MOSTRAR SERVICIOS DESPLEGADOS -->
                                                        checkservices


                            #=======================================#
                                        HEALTHCHECKS
                            #=======================================#
                            # COMPROBAR DOCKER --> checkdockerhealth
                            # COMPROBAR TODO --> checkall <reporte>
                            (si introducimos reporte nos crea un log)

#############################################################################################
#                                                                                           #
#############################################################################################
"
    fi
}


