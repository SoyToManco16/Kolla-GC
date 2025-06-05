#!/bin/bash

# Script para descargar solo custom-commands.sh desde tu repo de GitHub y copiarlo a /etc/kolla/gc-tools

# URL del archivo raw en GitHub (ajusta la rama si usas “master” en lugar de “main”)
REMOTE_FILE_URL="https://raw.githubusercontent.com/SoyToManco16/Kolla-GC/main/custom-commands.sh"

# Directorio destino
DEST_DIR="/etc/kolla/gc-tools"
DEST_FILE="$DEST_DIR/custom-commands.sh"

# 1. Comprobar conexión a GitHub (opcional, pero ayuda a detectar problemas de red)
if ! curl --head --silent --fail "https://github.com/SoyToManco16/Kolla-GC" >/dev/null; then
  echo "ERROR: No se puede acceder a GitHub o al repositorio. Comprueba tu conexión."
  exit 1
fi

# 2. Crear el directorio destino si no existe
if [ ! -d "$DEST_DIR" ]; then
  sudo mkdir -p "$DEST_DIR" || { echo "ERROR: No se pudo crear $DEST_DIR"; exit 1; }
fi

# 3. Descargar el archivo solo si existe (curl -f retorna error si no se encuentra)
echo "Descargando custom-commands.sh desde tu GitHub..."
if sudo curl -fsSL "$REMOTE_FILE_URL" -o "$DEST_FILE"; then
  sudo chmod +x "$DEST_FILE"
  echo "Éxito: custom-commands.sh se ha guardado en $DEST_FILE"
else
  echo "ERROR: Fallo al descargar custom-commands.sh. Comprueba que la ruta y la rama sean correctas."
  exit 1
fi
