#!/bin/bash

# Función para obtener la memoria total del sistema
get_total_memory() {
    total_mem_mb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    total_mem_gb=$((total_mem_mb / 1024))
    echo "$total_mem_gb"
}

# Función para verificar si existe un archivo de intercambio
check_swap_existence() {
    if grep -q "/swapfile" /proc/swaps; then
        echo "El archivo de intercambio ya existe."
        read -rp "¿Deseas borrar el archivo de intercambio existente? (S/n): " delete_swap
        if [[ "$delete_swap" == "S" || "$delete_swap" == "s" ]]; then
            echo "Borrando el archivo de intercambio existente..."
            swapoff /swapfile
            rm -f /swapfile
            sed -i '/\/swapfile/d' /etc/fstab
            echo "Archivo de intercambio existente eliminado."
        else
            echo "Saliendo del script."
            exit 0
        fi
    fi

    # Escanear el sistema para buscar más archivos swap y eliminarlos si se encuentran
    additional_swapfiles=$(grep -E '/[a-zA-Z0-9/_-]+.swap' /proc/swaps | awk '{print $1}')
    if [ -n "$additional_swapfiles" ]; then
        echo "Se han encontrado archivos de intercambio adicionales:"
        echo "$additional_swapfiles"
        read -rp "¿Deseas eliminar estos archivos de intercambio adicionales? (S/n): " delete_additional_swap
        if [[ "$delete_additional_swap" == "S" || "$delete_additional_swap" == "s" ]]; then
            echo "Eliminando archivos de intercambio adicionales..."
            for swapfile in $additional_swapfiles; do
                swapoff "$swapfile"
                rm -f "$swapfile"
                sed -i "/$swapfile/d" /etc/fstab
            done
            echo "Archivos de intercambio adicionales eliminados."
        fi
    fi
}

# Función para verificar si el usuario tiene permisos de root
check_root_permissions() {
    if [ "$EUID" -ne 0 ]; then
        echo "Por favor ejecuta el script como root."
        exit 1
    fi
}

# Función para agregar entrada al archivo /etc/fstab
add_to_fstab() {
    echo "/swapfile none swap sw 0 0" >>/etc/fstab
}

# Función para mostrar el menú de opciones
show_menu() {
    clear
    echo "David Enrique Zayas Pina"
    echo "espero les sea de utilidad"
    echo "==============================="
    echo "  Menú de Configuración SWAP  "
    echo "==============================="
    echo "1) Crear archivo de intercambio y activar"
    echo "2) Mostrar información sobre el intercambio"
    echo "3) Salir"
    echo "==============================="
}

# Función para crear y activar el archivo de intercambio
create_swap() {
    total_mem_mb=$(get_total_memory)
    estimated_swap=$((total_mem_mb * 2)) # Estimación: el doble de la memoria RAM

    check_swap_existence
    check_root_permissions

    read -rp "Introduce el tamaño deseado para el archivo de intercambio (en MB, dejar en blanco para utilizar $estimated_swap MB): " swap_size_input
    swap_size_input="${swap_size_input:-$estimated_swap}"

    echo "Creando archivo de intercambio de $swap_size_input MB..."
    fallocate -l "${swap_size_input}M" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

    # Agregar entrada al archivo /etc/fstab para hacer el intercambio persistente
    add_to_fstab

    echo "El archivo de intercambio se ha creado y activado correctamente."
    read -rp "Presiona Enter para continuar..."
}

# Función para mostrar información sobre el intercambio
show_swap_info() {
    echo "Información sobre el intercambio:"
    swapon --show
    free -h
    read -rp "Presiona Enter para continuar..."
}

# Main
while true; do
    show_menu
    read -rp "Selecciona una opción: " option
    case $option in
    1)
        create_swap
        ;;
    2)
        show_swap_info
        ;;
    3)
        echo "Saliendo del script."
        exit 0
        ;;
    *)
        echo "Opción inválida. Por favor, selecciona una opción válida."
        ;;
    esac
done
