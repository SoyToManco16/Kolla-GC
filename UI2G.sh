#!/bin/bash

# Script creado para automatizar la descarga y subida de imágenes de OpenStack (Upload Images 4 Glance)

# Cargar credenciales
source /etc/kolla/admin-openrc.sh

# Mostrar imágenes subidas en glance
openstack image list
echo "Porfavor no descargue una imágen que ya está subida en glance, esto puede causar graves problemas en al nube"
read -p "Intro para continuar..."

# === FUNCIONES PARA LISTAR DIRECTORIOS DE IMÁGENES ===

# LISTAR REPO UBUNTU 
function llist-images-from-ubuntu-repo {
    echo "Listando directorio...."
    curl -s https://cloud-images.ubuntu.com/ | \
    grep -oP '<a href="\K[^"]+/' | while read folder; do

        # Buscar línea original donde aparece ese folder
        line=$(curl -s https://cloud-images.ubuntu.com/ | grep "$folder</a>")

        # Extraer descripción si la hay (después de la fecha y el guión)
        desc=$(echo "$line" | sed -E 's/.*[0-9]{2}:[0-9]{2}[[:space:]]+-[[:space:]]+//')

        # Mostrar solo las versiones LTS
        if [[ "$desc" == *"LTS"* ]]; then
            echo "${folder%%/} - ${desc}"
        fi
    done
    echo ""
    read -p "Seleccione la versión que quiere (minúsculas): " UBU_VERSION
    echo "UBU_VERSION"
}

# LISTAR REPO ROCKY
function list-images-from-rocky-repo-and-upload {
    echo "=== REPOSITORIO ROCKY LINUX (QCOW2) ==="
    read -p "¿Qué tipo de versión desea listar? (8 o 9): " ver_base

    if [[ "$ver_base" != "8" && "$ver_base" != "9" ]]; then
        echo "Opción no válida"
        return
    fi

    echo "Listando versiones de Rocky Linux $ver_base..."
    rocky_versions=$(curl -s https://dl.rockylinux.org/vault/rocky/ | \
        grep -oP "(?<=<a href=\")$ver_base[^/]+/" | sed 's:/$::')

    if [[ -z "$rocky_versions" ]]; then
        echo "No se encontraron versiones para Rocky Linux $ver_base"
        return
    fi

    echo ""
    echo "$rocky_versions" | nl
    echo ""
    read -p "Seleccione la versión exacta (por ejemplo, 8.7): " rocky_ver
    echo "Versión seleccionada: $rocky_ver"

    image_url="https://dl.rockylinux.org/vault/rocky/$rocky_ver/images/x86_64/"

    echo "Buscando archivos .qcow2 en: $image_url"
    echo ""

    qcow_list=($(curl -s "$image_url" | grep -oP '(?<=<a href=")[^"]+\.qcow2'))

    if [[ ${#qcow_list[@]} -eq 0 ]]; then
        echo "No se encontraron archivos .qcow2 en esa versión"
        return
    fi

    echo "Archivos .qcow2 disponibles:"
    for i in "${!qcow_list[@]}"; do
        printf "[%d] %s\n" "$i" "${qcow_list[$i]}"
    done

    echo ""
    read -p "Seleccione el número del archivo que desea descargar: " idx

    if ! [[ "$idx" =~ ^[0-9]+$ ]] || [[ "$idx" -lt 0 || "$idx" -ge ${#qcow_list[@]} ]]; then
        echo "Índice inválido"
        return
    fi

    selected_file="${qcow_list[$idx]}"
    echo "Descargando $selected_file desde $image_url"
    
    # Descargar la imagen seleccionada
    wget -c "$image_url$selected_file" -O "/tmp/$selected_file"

    # Subir la imagen a Glance automáticamente
    glance_image_name="$rocky_ver-$(basename $selected_file)"
    echo "Subiendo la imagen a Glance con el nombre: $glance_image_name"
    
    openstack image create \
        --file "/tmp/$selected_file" \
        --disk-format qcow2 \
        --container-format bare \
        --public \
        --tag rocky \
        --property os_distro=rockylinux \
        "$glance_image_name"

    if [[ $? -eq 0 ]]; then
        echo "Imagen subida correctamente a Glance."
    else
        echo "Hubo un error al subir la imagen a Glance."
    fi

    # Devolver la versión descargada para su uso posterior
    echo "Versión descargada y subida: $rocky_ver"
}

# SUBIR IMÁGEN A GLANCE (UBUNTU)

function upload-image-ubuntu() {
    local ubu_version=$1
    # Definir la URL de la imagen en función de la versión seleccionada
    case $ubu_version in
        bionic)
            img_url="https://cloud-images.ubuntu.com/bionic/20230425/bionic-server-cloudimg-arm64.img"
            ;;
        focal)
            img_url="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
            ;;
        jammy)
            img_url="https://cloud-images.ubuntu.com/jammy/20250313/jammy-server-cloudimg-amd64.img"
            ;;
        noble)
            img_url="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
            ;;
        trusty)
            img_url="https://cloud-images.ubuntu.com/releases/14.04/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img"
            ;;
        xenial)
            img_url="https://cloud-images.ubuntu.com/releases/16.04/release/ubuntu-16.04-server-cloudimg-amd64-disk1.img"
            ;;
        *)
            echo "Versión no válida"
            return 1
            ;;
    esac

    # Descargar la imagen
    echo "Descargando $ubu_version..."
    wget -O /tmp/ubuntu_image.img "$img_url"
    
    # Subir la imagen a Glance
    openstack image create --disk-format qcow2 --container-format bare --public --file /tmp/ubuntu_image.img "$ubu_version"
    echo "Imagen $ubu_version subida a Glance"
}


# PREGUNTAR AL USUARIO TIPO DE IMÁGEN PARA DESCARGAR Y CARGAR EN GLANCE
function main {
    clear
    echo "=== DIRECTORIOS DE IMÁGENES DISPONIBLES ==="
    echo "1) Ubuntu"
    echo "2) Rocky Linux"
    read -p "Qué tipo de imagen quieres descargar: " image
    echo ""
    
    case $image in 
        1) 
            llist-images-from-ubuntu-repo
            upload-image-ubuntu "$UBU_VERSION"
            ;;
        2)
            list-images-from-rocky-repo-and-upload
            ;;
        *)
            echo "Opción no válida"
            ;;
    esac
}

# Main
main