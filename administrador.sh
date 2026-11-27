#!/usr/bin/env bash

TITULO_PROYECTO="Asistente Interactivo de Control y Auditoría de Procesos"
GRUPO="Grupo #7"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

mostrar_encabezado() {
    clear
    echo -e "======================================================================"
    echo -e "        UNIVERSIDAD TECNOLÓGICA DE PANAMÁ - FISC                      "
    echo -e "  Proyecto: ${TITULO_PROYECTO}"
    echo -e "  ${GRUPO} "
    echo -e "======================================================================\n"
}

# ---------- Opciones pendientes (reemplazar cuando estén listas) ----------
opcion_1() {
    echo -e "\nOpción 1 - Filtro de procesos (pendiente de agregar)."
    read -rp "Presione Enter para volver al menú..."
}

opcion_2() {
    echo -e "\nOpción 2 - Arbol completo de PID (pendiente de agregar)."
    read -rp "Presione Enter para volver al menú..."
}

# ---------- Opción 3: Revisión de archivos abiertos y auditoría de red ----------
opcion_3() {
    local modulo="$SCRIPT_DIR/revision_archivo_auditoria.sh"

    if [ ! -f "$modulo" ]; then
        echo -e "\n[!] No se encontró '$modulo'."
        read -rp "Presione Enter para volver al menú..."
        return
    fi

    bash "$modulo"
    echo
    read -rp "Presione Enter para volver al menú..."
}

opcion_4() {
    echo -e "\nOpcion 4 - Control de prioridad y senales (pendiente de agregar)."
    read -rp "Presione Enter para volver al menú..."
}

opcion_5() {
    echo -e "\nOpcion 5 - Monitor en tiempo real (pendiente de agregar)."
    read -rp "Presione Enter para volver al menú..."
}

# ---------- Menú principal ----------
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
        echo -e "  [0] Salir del aplicativo\n"
        echo -e "----------------------------------------------------------------------"
        read -rp "Seleccione una opción [0-5]: " opcion

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

menu_principal