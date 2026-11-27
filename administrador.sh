#!/usr/bin/env bash

TITULO_PROYECTO="Asistente Interactivo de Control y Auditoria de procesos"
GRUPO="Grupo #7"

mostrar_encabezado() {
    clear
    echo -e "=============================================================================="
    echo -e "        UNIVERSIDAD TECNOLÓGICA DE PANAMÁ - FISC                            "
    echo -e "  Proyecto: ${TITULO_PROYECTO}"
    echo -e "  ${GRUPO} "
    echo -e "==============================================================================\n"
}

opcion_5() {
    mostrar_encabezado
    echo -e "=============================================================================="
    echo -e "MONITOR EN TIEMPO REAL"
    echo -e "=============================================================================="
    local tipo valor intervalo salida_bucle

    echo -e "Filtrar por:\n [1] Usuario\n [2] PID especifico\n"
    read -rp "Seleccione filtro [1-2] [1]: " tipo
    tipo="${tipo:-1}"

    if [[ "$tipo" == "1" ]]; then
        local defecto
        defecto="$(whoami)"
        read -rp "Ingrese nombre de usuario [${defecto}]: " valor
        valor="${valor:-$defecto}"

        if ! id "$valor" >/dev/null 2>&1; then
            echo "[!] Error: El usuario '$valor' no existe en el sistema."
            return
        fi

        read -rp "Intervalo de refresco en segundos [2]: " intervalo
        intervalo="${intervalo:-2}"
        if [[ ! "$intervalo" =~ ^[0-9]+$ ]] || (( intervalo < 1 )); then
            intervalo=2
        fi

        salida_bucle=0
        trap 'salida_bucle=1' INT

        while (( salida_bucle == 0 )); do
            clear
            echo "=============================================================================="
            echo "  MONITOR EN TIEMPO REAL POR USUARIO: ${valor}  |  Refresco: ${intervalo}s  |  [Ctrl+C para salir]"
            echo "=============================================================================="
            echo "Hora: $(date '+%H:%M:%S')  |  Host: $(hostname)"
            echo ""
            ps -u "$valor" -o pid,ppid,stat,%cpu,%mem,etime,comm --sort=-%cpu 2>/dev/null | head -n 25
            sleep "$intervalo"
        done

        trap - INT
        echo -e "\n[✔] Monitor detenido."

    elif [[ "$tipo" == "2" ]]; then
        read -rp "Ingrese el PID a monitorear: " valor
        if [[ ! "$valor" =~ ^[0-9]+$ ]] || [[ ! -d "/proc/$valor" ]]; then
            echo "[!] Error: El PID '$valor' no es válido o el proceso ya no existe."
            return
        fi

        read -rp "Intervalo de refresco en segundos [1]: " intervalo
        intervalo="${intervalo:-1}"
        if [[ ! "$intervalo" =~ ^[0-9]+$ ]] || (( intervalo < 1 )); then
            intervalo=1
        fi

        salida_bucle=0
        trap 'salida_bucle=1' INT

        while (( salida_bucle == 0 )); do
            clear
            echo "=============================================================================="
            echo "  MONITOR EN TIEMPO REAL POR PID: ${valor}  |  Refresco: ${intervalo}s  |  [Ctrl+C para salir]"
            echo "=============================================================================="
            echo "Hora: $(date '+%H:%M:%S')  |  Host: $(hostname)"
            echo ""
            if [[ ! -d "/proc/$valor" ]]; then
                echo "[!] El proceso con PID ${valor} ha finalizado."
                break
            fi
            ps -p "$valor" -o pid,ppid,user,stat,nice,%cpu,%mem,rss,etime,comm
            sleep "$intervalo"
        done

        trap - INT
        echo -e "\n[✔] Monitor por PID detenido."
    else
        echo "[!] Filtro inválido."
    fi
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
	echo -e "  [6] Opcion 6 - Buscar procesos por nombre"
        echo -e "  [0] Salir\n"
        echo -e "----------------------------------------------------------------------"
        read -rp "Seleccione una opción [0-6]: " opcion

        case $opcion in
            1) Filtrar_procesos ;;
            2) opcion_2 ;;
            3) opcion_3 ;;
            4) opcion_4 ;;
	    5) opcion_5 ;;
	    6) Buscar_procesos ;;
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
source "$RUTA_SCRIPT/filtrar_procesos.sh"
source "$RUTA_SCRIPT/buscar_procesos.sh"
source "$RUTA_SCRIPT/prueba_arbol.sh"

opcion_3() {
    local modulo="$RUTA_SCRIPT/revision_archivo_auditoria.sh"

    if [ ! -f "$modulo" ]; then
        echo -e "\n[!] No se encontró '$modulo'."
        read -rp "Presione Enter para volver al menú..."
        return
    fi

    bash "$modulo"
    echo
    read -rp "Presione Enter para volver al menú..."
}

menu_principal
