#!/usr/bin/env bash

TITULO_PROYECTO="Asistente Interactivo de Control y Auditorioa de procesos"
GRUPO="Grupo #7"

mostrar_encabezado() {
    clear
    echo -e "======================================================================"
    echo -e "        UNIVERSIDAD TECNOLÓGICA DE PANAMÁ - FISC                      "
    echo -e "  Proyecto: ${TITULO_PROYECTO}"
    echo -e "  ${GRUPO} "
    echo -e "======================================================================\n"
}

menu_principal() {
    local opcion
    while true; do
        mostrar_encabezado
        echo -e "MENÚ PRINCIPAL DE OPCIONES:\n"
        echo -e "  [1] Opción 1 - Filtro de procesos"
        echo -e "  [2] Opción 2 - Arbol completo de PID"
        echo -e "  [3] Opción 3 - Inspeccion de recursos de un PID"
        echo -e "  [4] Opcion 4 - Control de prioridad y senales"
	echo -e "  [5] Opcion 5 - Monitor en tiempo real"
        echo -e "  [0] Salir\n"
        echo -e "----------------------------------------------------------------------"
        read -rp "Seleccione una opción [0-4]: " opcion

        case $opcion in
            1) opcion_1 ;;
            2) opcion_2 ;;
            3) opcion_3 ;;
            4) opcion_4 ;;
	    5) opcion_5 ;;
	    0)
                echo -e "\nSaliendo del sistema.\n"
                exit 0
                ;;
            *)
                echo -e "\n[!] Opción inválida. Intente nuevamente."
                sleep 1.5
                ;;
        esac
    done
}

# Carga el modulo de control de procesos (opcion 4) desde esta misma carpeta.
RUTA_SCRIPT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$RUTA_SCRIPT/control_procesos.sh" ]]; then
    echo "[ERROR] No se encontro control_procesos.sh en $RUTA_SCRIPT" >&2
    exit 1
fi
source "$RUTA_SCRIPT/control_procesos.sh"

menu_principal
