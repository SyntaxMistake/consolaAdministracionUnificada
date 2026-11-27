#!/bin/bash
#autor : Francesco
#opcion 6 : Busca procesos por coincidencia parcial de nombre o por nombre exacto de binario
Buscar_procesos() {
    clear
    echo "===== BUSCAR PROCESOS ====="
    echo "1) Búsqueda parcial (el nombre contiene el texto)"
    echo "2) Búsqueda exacta (el nombre coincide completo)"
    echo
    read -p "Elija una opción [1-2]: " opcion
    read -p "Ingrese el nombre del proceso: " nombre
    if [ -z "$nombre" ]; then
        echo "Debe escribir un nombre de proceso."
        read -p "Presione Enter para continuar..."
        return
    fi
    case $opcion in
        1)
            # Búsqueda parcial: muestra los procesos cuyo nombre contiene el texto (ej: "sle" encuentra "sleep")
            if pgrep -a "$nombre"; then
                echo "Se encontraron procesos que contienen '$nombre'."
            else
                echo "No se encontró ningún proceso que contenga '$nombre'."
            fi
            ;;
        2)
            # Búsqueda exacta: el nombre debe ser igual al texto (ej: "sle" no encuentra nada, "sleep" sí)
            if pgrep -ax "$nombre"; then
                echo "Se encontraron procesos llamados exactamente '$nombre'."
            else
                echo "No existe ningún proceso llamado exactamente '$nombre'."
            fi
            ;;
        *)
            echo "Opción no válida. Debe elegir 1 o 2."
            ;;
    esac
    read -p "Presione Enter para continuar..."
}

