#!/bin/bash

####################################
# CREACIÓN DE USUARIO SCP
####################################
USUARIO="uploader"
DIR_UPLOAD="/etc/kolla/scp_images"
WATCHER_FILE="/etc/systemd/system/img2qcow2-watcher.service"

# 1. Crear el usuario si no existe
if id "$USUARIO" &>/dev/null; then
    echo "[+] El usuario '$USUARIO' ya existe"
else
    echo "[+] Creando usuario '$USUARIO'"
    sudo useradd -m -d $DIR_UPLOAD -s /bin/bash $USUARIO
fi

# 2. Asegurar que tiene shell válida
echo "[+] Asignando shell válida a '$USUARIO'"
sudo usermod -s /bin/bash "$USUARIO"

# 4. Asignar permisos
echo "[+] Estableciendo permisos al directorio"
sudo chown "$USUARIO:$USUARIO" "$DIR_UPLOAD"
sudo chmod 755 "$(dirname "$DIR_UPLOAD")"
sudo chmod 755 "$DIR_UPLOAD"

sudo passwd $USUARIO

echo "[:D] Usuario $USUARIO creado con exito"
echo "Se recomienda el uso de WinSCP para subida de imágenes"

####################################
# CREACIÓN DEL SERVICIO 
####################################

echo "[+] Creando servicio para el watcher"

if [ ! -f "$WATCHER_FILE" ]; then
    sudo tee "$WATCHER_FILE" > /dev/null <<EOF
[Unit]
Description=IMG2QCOW2 Watcher
After=network.target

[Service]
ExecStart=/etc/kolla/gc-tools/qcow2-watcher.sh
Type=simple
Restart=always
PIDFile=/run/monitoring.pid

[Install]
WantedBy=multi-user.target
EOF

    echo "[+] Servicio creado en $WATCHER_FILE"
else
    echo "[*] Servicio ya existe en $WATCHER_FILE"
fi

echo "[+] Recargando demonios"
sudo systemctl daemon-reload

echo "[+] Arrancando watcher"
sudo systemctl start img2qcow2-watcher.service
sudo systemctl enable img2qcow2-watcher.service

echo "[!] Instalando dependencias del watcher"
sudo apt install inotify-tools -y
sudo apt-get install qemu-utils

echo "[+] Watcher esperando imágenes !!"
