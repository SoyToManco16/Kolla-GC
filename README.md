# Kolla-GC
Script de automatización para el despliegue de GoyaCloud.

### COMO DESPLEGAR ?
Acceder a el archivo de guía o ver video adjunto en la documentación.

### ACTUALIZACIÓN
Hemos añadido un nuevo comando para poder actualizar los comandos de manera automática <br>
con el uso de `updategccommands`.

Ahora `gccommands` se puede ejecutar con parámetros para mostrar menos texto. <br>

Parámetros disponibles: `"gc" "keystone" "img" "red" "nova" "horizon" "misc" "health"`


## REQUISITOS PREVIOS:
**TENER EL NETPLAN BIEN CONFIGURADO**

```shell
# Ejemplo para VM con 3 interfaces (2 Puentes y 1 para trabajo (solo-anfitrión)) 

network:
  version: 2
  ethernets:
    enp0s3:
      addresses:
      - "192.168.18.200/24"
      nameservers:
        addresses:
        - 8.8.8.8
        - 1.1.1.1
        search: []
      routes:
      - to: "default"
        via: "192.168.18.1"
    enp0s8:
      dhcp4: false # Reservada para Neutron (Siempre en false)
    enp0s9:
      dhcp4: true # En el servidor no tenemos esta interfaz porque es para SSH

```


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
---
##### [!] VARIABLES REDES
```shell
INTERNAL_IP="192.168.18.159"
NETWORK_INTERFACE="enp0s3"
INTERNAL_INTERFACE="enp0s8"
```

##### [!] VARIABLES BASE
```shell
BASE_DISTRO="ubuntu"
VIRT_TYPE="qemu"
```

##### [!] VARIABLES DIRECTORIOS (NO CAMBIAR A MENOS QUE SEPAMOS QUE HACEMOS)
```shell
CLOUDS_DIR="/etc/kolla/clouds.yaml" 
KOLLA_GC_DIR=$(pwd)
GCTOOLS_CUSTOM='source /etc/kolla/gc-tools/custom-commands.sh'
```
---

**Ahora vamos con la configuración de el gc-runonce**
gc-runonce es un script que hemos diseñado basándonos en init-runonce de el propio Kolla-Ansible para desplegar el contenido de la nube (Redes, instancias...).
Debemos de ajustar las variables del principio del script a nuestra manera.
Solo debe de ejecutarse una vez.

**VARIABLES PARA GC-RUNONCE**
---
##### [!] VARIABLES PARA RED EXTERNA

```shell
EXTERNAL_NETWORK_NAME="red_externa" # Nombre de la red externa
EXTERNAL_SUBNET_RANGE="192.168.210.0/24" # Rango para la subnet
EXTERNAL_GATEWAY="192.168.210.1" # Puerta de enlace
POOL_START="192.168.210.150" # Inicio del pool DHCP dentro de la subnet
POOL_END="192.168.210.199" # Final del pool DHCP dentro de la subnet
```

##### [!] VARIABLES PARA RED INTERNA
```shell
INTERNAL_NETWORK_NAME="red_interna_vms" # Nombre de la red interna
INTERNAL_NETWORK_SUBNET_RANGE="10.0.0.0/24" # Rango para la subnet
INTERNAL_NETWORK_GATEWAY="10.0.0.1" # Puerta de enlace para la subnet
INTERNAL_NETWORK_DNS="8.8.8.8" # Servidor DNS para la red interna
```

##### [!] VARIABLES PARA CUOTA DE PROYECTO
```shell
VMS="10" # Número de máquinas que se pueden crear 
CPUS="16" # Número de CPUs para el proyecto
RAM="22000" # Memoria RAM máxima para el proyecto (En mbs, Ej: 8192)
FLOATING_IPS="10" # IPs Flotantes máximas
SECURITY_GROUPS="20" # Grupos de seguridad (Reglas) máximas
KEY_PAIRS="20" # Pares de claves máximos
```
---
#### CUANDO TODO ESTÉ CONFIGURADO 
`./Kolla.sh` --> Y mucha paciencia, cuando veamos que se está configurando el Watcher (Para subida de imágenes automáticas) debemos de introducir la contraseña para este usuario.

#### ¿COMO FUNCIONA EL WATCHER?
El watcher o centinela, es un servicio que hemos desarrollado para automatizar la subida de imágenes a la nube via SCP, está compuesto por código bash y una herramienta llamada inotify, que se encarga de detectar cambios en un directorio y tiene la capacidad de no usar recursos mientras no está funcionando.<br>
El funcionamiento es el siguiente:<br>
Se crea un usuario en el sistema llamado **Uploader** al cual a mitad del despliegue nos hará configurarle una contraseña para poder acceder a el desde afuera del servidor.
Este usuario tiene predefinido un directorio `/etc/kolla/scp_images`. 
<br>
Cuando subimos una imagen a través de el, el la interpretará de las siguientes maneras:
Si la imagen está en formato **qcow2** automáticamente la subirá a Glance y estará lista para virtualizar.<br>
Si la imágen está en uno de los siguientes formatos (**vmdk, img, raw, vdi**), comenzará a convertir la imágen, luego la subirá y después eliminará el residuo de la imagen para evitar colapsar el almacenamiento del servidor.
<br>Si se introduce un archivo con otra extensión, este lo eliminará automáticamente.
Todos los movimientos que el watcher realice se verán reflejados en el siguiente archivo `/etc/kolla/watcher.log`.

#### HERRAMIENTAS GC
Herramientas desarrolladas con la finalidad de automatizar ciertos puntos y la monitorización del servidor.
---

```shell
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
```

#### Créditos
Proyecto creado y mantenido por SoyToManco16 y RubénNoEsToManco como parte del despliegue de infraestructura cloud educativa GoyaCloud.
