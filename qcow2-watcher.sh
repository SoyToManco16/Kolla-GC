#!/bin/bash

####################################
# Vars
####################################

WATCHER_DIR="/etc/kolla/scp_images"
EXTENSIONS=("qcow2" "raw" "img" "vmdk" "vdi")
WATCHER_LOG_FILE="/etc/kolla/watcher.log"

####################################
# Funciones auxiliares
####################################

# CREAR LOGFILE

# Comprobar fichero
if [ ! -f "$WATCHER_LOG_FILE" ]; then
    touch "$WATCHER_LOG_FILE"
fi

# GENERAR TIMESTAMP

function timestamp() {
    local msg="$1"
    local now=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$now] $msg"
}

# FUNCIÓN PARA SUBIR IMÁGENES A GLANCE

function upload2glance() {
    local file="$1"
    local name=$(basename "$file")

    if openstack image list --name "$name" -f value -c Name | grep -Fxq "$name"; then
        timestamp "La imagen '$name' ya existe en Glance. No se subirá." >> "$WATCHER_LOG_FILE"
        rm -f "$file"
        return 1
    else
        openstack image create "$name" --file "$file" --disk-format qcow2 --container-format bare --public
        if [ $? -eq 0 ]; then
            timestamp "Imagen '$name' subida correctamente a Glance." >> "$WATCHER_LOG_FILE"
            rm -f "$file"
            return 0
        else
            timestamp "Error al subir '$name' a Glance." >> "$WATCHER_LOG_FILE"
            return 1
        fi
    fi
}

# FUNCIÓN PARA CONVERTIR IMÁGENES A QCOW2

function img2qcow2() {
    local file="$1"
    local base="${file%.*}"
    local ext="${file##*.}"
    local qcow2file="${base}.qcow2"

    local tmpfile="${qcow2file}.tmp"

    qemu-img convert -f "$ext" -O qcow2 "$file" "$tmpfile"
    if [ $? -eq 0 ]; then
        mv "$tmpfile" "$qcow2file"
        timestamp "Convertida '$file' → '$qcow2file'" >> "$WATCHER_LOG_FILE"

        upload2glance "$qcow2file"
        if [ $? -eq 0 ]; then
            rm -f "$file"
        else
            timestamp "Error al subir imagen convertida '$qcow2file'" >> "$WATCHER_LOG_FILE"
        fi
    else
        timestamp "Error al convertir '$file' a QCOW2" >> "$WATCHER_LOG_FILE"
        rm -f "$tmpfile" 2>/dev/null
    fi
}

# FUNCIÓN DEL CENTINELA

function start_watcher() {
    timestamp "Watcher iniciado. Vigilando $WATCHER_DIR" >> "$WATCHER_LOG_FILE"

    inotifywait -m -e close_write --format '%f' "$WATCHER_DIR" | while read FILE; do
        full_path="$WATCHER_DIR/$FILE"
        ext="${FILE##*.}"
        ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

        # Verifica si el archivo tiene una extensión válida
        is_valid=false
        for valid_ext in "${EXTENSIONS[@]}"; do
            if [[ "$ext_lower" == "$valid_ext" ]]; then
                is_valid=true
                break
            fi
        done

        if ! $is_valid; then
            timestamp "Archivo '$FILE' con extensión no válida. Eliminando..." >> "$WATCHER_LOG_FILE"
            rm -f "$full_path"
            continue
        fi

        # Procesar según tipo
        case "$ext_lower" in
            qcow2)
                upload2glance "$full_path"
                ;;
            raw|img|vmdk|vdi)
                img2qcow2 "$full_path"
                ;;
        esac
    done
}



start_watcher 