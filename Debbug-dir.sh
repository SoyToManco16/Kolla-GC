# DEBUGGEAR EL PUTO DIRECTORIO
sudo apt install dos2unix -y

DIRECTORIO="."
for archivo in "$DIRECTORIO"/*; do
    if [ -f "$archivo" ]; then
        dos2unix "$archivo"
        echo "Convertido $archivo"
    fi
done
