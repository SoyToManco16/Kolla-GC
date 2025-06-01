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

# Crear logfile si no existe
if [ ! -f "$WATCHER_LOG_FILE" ]; then
    touch "$WATCHER_LOG_FILE"
fi

# Generar timestamp para logs
function timestamp() {
    local msg="$1"
    local now
    now=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$now] $msg"
}

# Función para subir imágenes a Glance
function upload2glance() {
    local file="$1"
    # Nombre en Glance: nombre del fichero sin extensión
    local base_name
    base_name=$(basename "$file" .qcow2)

    timestamp "Intentando subir '$file' a Glance con nombre '$base_name'..." >> "$WATCHER_LOG_FILE"

    # Si ya existe una imagen con ese nombre, no subirla de nuevo
    if openstack image list --name "$base_name" -f value -c Name | grep -Fxq "$base_name"; then
        timestamp "La imagen '$base_name' ya existe en Glance. Eliminando local." >> "$WATCHER_LOG_FILE"
        rm -f "$file"
        return 1
    fi

    # Subir a Glance
    if openstack image create "$base_name" \
            --file "$file" \
            --disk-format qcow2 \
            --container-format bare \
            --public >> "$WATCHER_LOG_FILE" 2>&1; then
        timestamp "Imagen '$base_name' subida correctamente a Glance." >> "$WATCHER_LOG_FILE"
        rm -f "$file"
        return 0
    else
        timestamp "Error al subir '$base_name' a Glance. Verificar manualmente." >> "$WATCHER_LOG_FILE"
        return 1
    fi
}

# Función para convertir imágenes a QCOW2
function img2qcow2() {
    local file="$1"
    local base="${file%.*}"
    local qcow2file="${base}.qcow2"
    local tmpfile="${qcow2file}.tmp"

    # Detectar formato real del archivo con qemu-img info
    local actual_format
    actual_format=$(qemu-img info "$file" 2>/dev/null | awk -F ': ' '/file format/ {print $2}' | tr -d '\r')

    if [ -z "$actual_format" ]; then
        timestamp "Error: no se pudo detectar el formato de '$file'. Saltando." >> "$WATCHER_LOG_FILE"
        return 1
    fi

    # Si ya es QCOW2, subir directamente
    if [[ "$actual_format" == "qcow2" ]]; then
        timestamp "El archivo '$file' ya está en formato QCOW2. Subiendo directo." >> "$WATCHER_LOG_FILE"
        upload2glance "$file"
        return
    fi

    # Convertir a QCOW2
    timestamp "Convirtiendo '$file' desde formato '$actual_format' a QCOW2..." >> "$WATCHER_LOG_FILE"
    if qemu-img convert -f "$actual_format" -O qcow2 "$file" "$tmpfile" 2>> "$WATCHER_LOG_FILE"; then
        mv "$tmpfile" "$qcow2file"
        timestamp "Convertida '$file' → '$qcow2file'." >> "$WATCHER_LOG_FILE"
        # Subir la QCOW2 resultante
        upload2glance "$qcow2file"
        if [ $? -eq 0 ]; then
            rm -f "$file"
        else
            timestamp "Error al subir imagen convertida '$qcow2file'." >> "$WATCHER_LOG_FILE"
        fi
    else
        timestamp "Error al convertir '$file' a QCOW2. Borrando '$tmpfile' si existe." >> "$WATCHER_LOG_FILE"
        rm -f "$tmpfile" 2>/dev/null
        return 1
    fi
}

# Función para eliminar archivos .tmp después de 10 minutos
function cleanup_tmp_files() {
    while true; do
        find "$WATCHER_DIR" -type f -name '*.tmp' -mmin +10 -exec rm -f {} \;
        sleep 600  # 10 minutos
    done
}

# Función principal del watcher
function start_watcher() {
    timestamp "Watcher iniciado. Vigilando $WATCHER_DIR" >> "$WATCHER_LOG_FILE"

    inotifywait -m -e close_write --format '%f' "$WATCHER_DIR" | while read -r FILE; do
        full_path="$WATCHER_DIR/$FILE"
        ext="${FILE##*.}"
        ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

        # Ignorar archivos .tmp (serán borrados por cleanup_tmp_files)
        if [[ "$FILE" == *.tmp ]]; then
            continue
        fi

        # Verificar extensión válida
        local is_valid=false
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

####################################
# Arranque de procesos
####################################

# Cargar variables de entorno
source "/etc/kolla/admin-openrc.sh"

# Iniciar limpieza de .tmp en segundo plano
cleanup_tmp_files &

# Iniciar el watcher
start_watcher
