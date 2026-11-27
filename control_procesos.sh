#!/usr/bin/env bash
# ==============================================================
# OPCION 6 - CONTROL INTERACTIVO DE PROCESOS
# Entorno: Ubuntu / WSL
# Requisitos: bash, procps (ps, renice), coreutils
# ==============================================================

# Este archivo se carga desde administrador.sh; evita cambiar opciones globales de Bash.

VERSION="2.0"
if [[ -t 1 ]]; then
    ROJO=$'\033[1;31m'; VERDE=$'\033[1;32m'; AMARILLO=$'\033[1;33m'
    AZUL=$'\033[1;34m'; CYAN=$'\033[1;36m'; MAGENTA=$'\033[1;35m'
    NEGRITA=$'\033[1m'; RESET=$'\033[0m'
else
    ROJO=""; VERDE=""; AMARILLO=""; AZUL=""; CYAN=""; MAGENTA=""; NEGRITA=""; RESET=""
fi

limpiar() { printf '\033[2J\033[H'; }
pausa() { echo; read -r -p "Presiona ENTER para continuar..." _; }

banner() {
    echo "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    printf "${CYAN}║${RESET}  ${NEGRITA}CENTRO DE CONTROL DE PROCESOS${RESET}  ${MAGENTA}v%s${RESET}                    ${CYAN}║${RESET}\n" "$VERSION"
    echo "${CYAN}║${RESET}  Prioridad, suspension, reanudacion y finalizacion           ${CYAN}║${RESET}"
    echo "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
}

validar_pid() {
    [[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -gt 0 ]] && [[ -d "/proc/$1" ]]
}

mostrar_proceso() {
    local pid="$1"
    echo
    echo "${AZUL}┌─ INFORMACION DEL PROCESO ────────────────────────────────────┐${RESET}"
    ps -p "$pid" -o pid=,ppid=,user=,ni=,stat=,etime=,comm= --no-headers 2>/dev/null |
        awk '{printf "  PID: %-8s PPID: %-8s Usuario: %-12s NI: %-4s Estado: %-6s Tiempo: %-10s Nombre: %s\n",$1,$2,$3,$4,$5,$6,$7}'
    echo "  Ejecutable: $(readlink -f "/proc/$pid/exe" 2>/dev/null || echo 'No disponible')"
    echo "  Comando:    $(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | cut -c1-180)"
    echo "${AZUL}└─────────────────────────────────────────────────────────────┘${RESET}"
}

confirmar() {
    local mensaje="$1" respuesta
    read -r -p "$mensaje Escribe SI para confirmar: " respuesta
    [[ "$respuesta" == "SI" ]]
}

comprobar_permiso() {
    local pid="$1"
    local propietario
    propietario="$(ps -p "$pid" -o user= 2>/dev/null | xargs || true)"
    if [[ "$EUID" -ne 0 && "$propietario" != "$(id -un)" ]]; then
        echo "${AMARILLO}[AVISO] El proceso pertenece a '$propietario'.${RESET}"
        echo "Es posible que necesites ejecutar el script con sudo."
        return 1
    fi
    return 0
}

accion_renice() {
    local pid="$1" actual nuevo
    actual="$(ps -p "$pid" -o ni= 2>/dev/null | xargs || echo '?')"
    echo
    echo "Prioridad actual (NI): $actual"
    echo "En Linux, un valor NI mayor significa menor prioridad de CPU."
    echo "Este módulo solo permite aumentar NI (reducir prioridad), de +1 a +19."
    read -r -p "Nuevo valor NI [1-19]: " nuevo
    if [[ ! "$nuevo" =~ ^([1-9]|1[0-9])$ ]]; then
        echo "${ROJO}[ERROR] Introduce un numero entre 1 y 19.${RESET}"
        return
    fi
    if ! confirmar "¿Reducir la prioridad del PID $pid a NI=$nuevo?"; then
        echo "Operacion cancelada."
        return
    fi
    if renice -n "$nuevo" -p "$pid"; then
        echo "${VERDE}[OK] Prioridad actualizada.${RESET}"
        ps -p "$pid" -o pid,ni,comm
    else
        echo "${ROJO}[ERROR] No se pudo cambiar la prioridad. Revisa permisos.${RESET}"
    fi
}

accion_senal() {
    local pid="$1" senal="$2" descripcion="$3"
    if ! confirmar "¿$descripcion el proceso PID $pid?"; then
        echo "Operacion cancelada."
        return
    fi
    if kill "-$senal" "$pid" 2>/dev/null; then
        echo "${VERDE}[OK] Senal $senal enviada al PID $pid.${RESET}"
        sleep 1
        if [[ -d "/proc/$pid" ]]; then
            echo "Estado actual:"
            ps -p "$pid" -o pid,stat,ni,comm
        else
            echo "El proceso ya no aparece en /proc."
        fi
    else
        echo "${ROJO}[ERROR] No se pudo enviar la senal. Puede faltar permiso o el PID ya no existir.${RESET}"
    fi
}

menu_pid() {
    local pid="$1" op
    while true; do
        limpiar
        banner
        if ! validar_pid "$pid"; then
            echo "${AMARILLO}El proceso ya no existe. Regresando al menu.${RESET}"
            pausa
            return
        fi
        mostrar_proceso "$pid"
        echo
        echo "  1) Reducir prioridad (renice)"
        echo "  2) Pausar proceso (SIGSTOP)"
        echo "  3) Reanudar proceso (SIGCONT)"
        echo "  4) Finalizar proceso (SIGTERM)"
        echo "  5) Actualizar informacion"
        echo "  0) Regresar"
        echo
        read -r -p "  Selecciona una accion: " op
        case "$op" in
            1)
                comprobar_permiso "$pid" || { pausa; continue; }
                accion_renice "$pid"; pausa
                ;;
            2)
                comprobar_permiso "$pid" || { pausa; continue; }
                accion_senal "$pid" "STOP" "Pausar"; pausa
                ;;
            3)
                comprobar_permiso "$pid" || { pausa; continue; }
                accion_senal "$pid" "CONT" "Reanudar"; pausa
                ;;
            4)
                comprobar_permiso "$pid" || { pausa; continue; }
                echo "${AMARILLO}Aviso: SIGTERM solicita al proceso que termine de forma ordenada.${RESET}"
                accion_senal "$pid" "TERM" "Solicitar la finalizacion de"; pausa
                ;;
            5) ;;
            0) return ;;
            *) echo "${ROJO}Opcion no valida.${RESET}"; pausa ;;
        esac
    done
}

menu_control_procesos() {
    local op pid
    while true; do
        limpiar
        banner
        echo
        echo "  1) Seleccionar proceso por PID"
        echo "  2) Buscar procesos por nombre"
        echo "  0) Salir"
        echo
        read -r -p "  Selecciona una opcion: " op
        case "$op" in
            1)
                read -r -p "  Introduce el PID: " pid
                if validar_pid "$pid"; then
                    menu_pid "$pid"
                else
                    echo "${ROJO}[ERROR] PID invalido o proceso inexistente.${RESET}"
                    pausa
                fi
                ;;
            2)
                read -r -p "  Nombre o parte del nombre: " patron
                if [[ -z "$patron" ]]; then
                    echo "Debes escribir un nombre."
                else
                    echo
                    pgrep -a -f -- "$patron" | head -n 30 || echo "No se encontraron coincidencias."
                fi
                pausa
                ;;
            0) echo "Regresando al menu principal."; return 0 ;;
            *) echo "${ROJO}Opcion no valida.${RESET}"; pausa ;;
        esac
    done
}

# Punto de entrada esperado por administrador.sh (opcion 4).
opcion_4() {
    menu_control_procesos
}
