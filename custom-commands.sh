#!/bin/bash

###################################
# VARIABLES PARA COMANDOS
###################################
CLOUDS_DIR="/etc/kolla/clouds.yaml" 
GCTOOLS_DIR="/etc/kolla/gc-tools"

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

###################################
# COMANDOS PARA CHECKEAR SERVICIOS
###################################



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

function gccommands {

    echo "
    #############################################################################################
    #                              COMANDOS PERSONALIZADOS PARA GC                              #
    #############################################################################################

    # CARGAR ENTORNO --> gcenv
    # CARGAR CREDENCIALES --> gcreds
    # CARGAR ENTORNO Y CREDS --> upgc
    # LLAMAR SCRIPT INTERACTIVO DE DESCARGA Y SUBIDA DE IMÁGENES LINUX --> ui2g
    # COMPROBAR ESTADO DEL WATCHER --> checkwatcher

    #############################################################################################
    #                                  ATAJOS PARA OPENSTACK CLI                                #
    #############################################################################################
                #                         MOSTRAR INFORMACIÓN                           #
                #########################################################################

    #=======================================#           #=======================================#   
                    KEYSTONE                                            GLANCE
    #=======================================#           #=======================================#   
    # MOSTRAR PROYECTOS --> listprojects                # MOSTRAR FLAVORS --> listflavors
    # MOSTRAR ROLES --> listroles                       # MOSTRAR IMÁGENES --> listimages
    # MOSTRAR USUARIOS --> listusers


    #=======================================#           #=======================================#  
                    NEUTRON                                               NOVA
    #=======================================#           #=======================================#
    # MOSTRAR REDES --> listnetworks                    # MOSTRAR INSTANCIAS --> listvms
    # MOSTRAR SUBREDES --> listsubnets
    # MOSTRAR ROUTERS --> listrouters
    # MOSTRAR PUERTOS --> listports
    # MOSTRAR FLOATING IPS --> listfloatingip

    #=======================================#           #=======================================#
                    HORIZON                                            MISCELANEA
    #=======================================#           #=======================================#
    # MOSTRAR INFO HORIZON --> horizon                  # MOSTRAR CUOTAS --> listquota <proyecto>
                                                            (Sin proyecto, usa el predeterminado)


                                #=======================================#
                                            HEALTHCHECKS
                                #=======================================#
                                

    #############################################################################################
    #                                                                                           #
    #############################################################################################
    "

}

