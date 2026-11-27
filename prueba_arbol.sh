nano prueba_arbol.sh

# ==============================================================================
# Opción 2: Árbol completo de PID y evaluación de impacto
# ==============================================================================

_leer_info_proceso() {
    local pid="$1"
    local ruta_proc="/proc/$pid"

    [[ -d "$ruta_proc" && -r "$ruta_proc/stat" ]] || return 1

    local stat_raw comm estado ppid uid usuario cmd
    stat_raw=$(<"$ruta_proc/stat") 2>/dev/null || return 1

    comm="${stat_raw#*\(}"
    comm="${comm%\)*}"

    local resto="${stat_raw#*\) }"
    read -r estado ppid _ <<<"$resto"

    [[ -n "$estado" && -n "$ppid" ]] || return 1

    uid=$(awk '/^Uid:/ {print $2; exit}' "$ruta_proc/status" 2>/dev/null)
    if [[ -n "$uid" ]]; then
        usuario=$(getent passwd "$uid" 2>/dev/null | cut -d: -f1)
        [[ -z "$usuario" ]] && usuario="$uid"
    else
        usuario="?"
    fi

    if [[ -r "$ruta_proc/cmdline" ]]; then
        cmd=$(tr '\0' ' ' <"$ruta_proc/cmdline" 2>/dev/null | sed 's/[[:space:]]*$//')
    fi
    [[ -z "$cmd" ]] && cmd="[$comm]"

    if ((${#cmd} > 48)); then
        cmd="${cmd:0:45}..."
    fi

    printf '%s|%s|%s|%s|%s\n' "$pid" "$ppid" "$usuario" "$estado" "$cmd"
}

_obtener_hijos_directos() {
    local objetivo_pid="$1"
    local p stat_raw resto ppid

    for p in /proc/[0-9]*; do
        p="${p##*/}"
        [[ "$p" =~ ^[0-9]+$ ]] || continue
        [[ -r "/proc/$p/stat" ]] || continue
        stat_raw=$(<"/proc/$p/stat") 2>/dev/null || continue
        resto="${stat_raw#*\) }"
        read -r _ ppid _ <<<"$resto"
        if [[ "$ppid" == "$objetivo_pid" ]]; then
            printf '%s\n' "$p"
        fi
    done | sort -n
}

_recorrer_arbol_pid() {
    local pid="$1"
    local prefijo="$2"
    local es_ultimo="$3"
    local profundidad="$4"

    local info
    if ! info=$(_leer_info_proceso "$pid"); then
        local conector="|-- "
        [[ "$es_ultimo" -eq 1 ]] && conector="\`-- "
        printf '%s%sPID %s [terminado durante consulta]\n' "$prefijo" "$conector" "$pid"
        return 0
    fi

    local p_pid p_ppid p_usr p_est p_cmd
    IFS='|' read -r p_pid p_ppid p_usr p_est p_cmd <<<"$info"

    local conector=""
    if ((profundidad > 0)); then
        if [[ "$es_ultimo" -eq 1 ]]; then
            conector="\`-- "
        else
            conector="|-- "
        fi
    fi

    printf '%s%sPID %s (%s) [%s] %s\n' "$prefijo" "$conector" "$p_pid" "$p_usr" "$p_est" "$p_cmd"

    if ((profundidad > 0)); then
        TOTAL_DESCENDIENTES=$((TOTAL_DESCENDIENTES + 1))
        ((profundidad > PROFUNDIDAD_MAX)) && PROFUNDIDAD_MAX="$profundidad"
    fi

    case "$p_est" in
        D) CONT_D=$((CONT_D + 1)) ;;
        Z) CONT_Z=$((CONT_Z + 1)) ;;
    esac

    if [[ -n "$USUARIO_OBJETIVO" && "$p_usr" != "$USUARIO_OBJETIVO" ]]; then
        OTRO_USUARIO=1
    fi

    local nuevo_prefijo="$prefijo"
    if ((profundidad > 0)); then
        if [[ "$es_ultimo" -eq 1 ]]; then
            nuevo_prefijo="${prefijo}    "
        else
            nuevo_prefijo="${prefijo}|   "
        fi
    fi

    local hijos=()
    while IFS= read -r h; do
        [[ -n "$h" ]] && hijos+=("$h")
    done < <(_obtener_hijos_directos "$p_pid")

    local total_hijos="${#hijos[@]}"
    local i=0
    for hijo_pid in "${hijos[@]}"; do
        i=$((i + 1))
        local ultimo_hijo=0
        ((i == total_hijos)) && ultimo_hijo=1
        _recorrer_arbol_pid "$hijo_pid" "$nuevo_prefijo" "$ultimo_hijo" $((profundidad + 1))
    done
}

opcion_2() {
    local entrada_pid=""

    printf '\n======================================================================\n'
    printf '  AUDITORIA DE ARBOL DE PROCESOS Y EVALUACION DE IMPACTO\n'
    printf '======================================================================\n'

    while true; do
        printf 'Ingrese el PID a inspeccionar (o "v" para volver al menu): '
        read -r entrada_pid

        [[ "$entrada_pid" == "v" || "$entrada_pid" == "V" ]] && return 0

        if [[ ! "$entrada_pid" =~ ^[1-9][0-9]*$ ]]; then
            printf '[!] Entrada invalida: ingrese un numero de PID entero positivo.\n\n'
            continue
        fi

        if [[ ! -d "/proc/$entrada_pid" ]]; then
            printf '[!] El PID %s no existe o ya finalizo.\n\n' "$entrada_pid"
            continue
        fi

        break
    done

    local info_raiz
    if ! info_raiz=$(_leer_info_proceso "$entrada_pid"); then
        printf '[!] No se pudo leer la informacion del PID %s (posible cierre inmediato o falta de permisos).\n' "$entrada_pid"
        printf 'Presione Enter para continuar...'
        read -r _
        return 0
    fi

    local raiz_pid raiz_ppid raiz_usr raiz_est raiz_cmd
    IFS='|' read -r raiz_pid raiz_ppid raiz_usr raiz_est raiz_cmd <<<"$info_raiz"

    TOTAL_DESCENDIENTES=0
    PROFUNDIDAD_MAX=0
    CONT_D=0
    CONT_Z=0
    OTRO_USUARIO=0
    USUARIO_OBJETIVO="$raiz_usr"

    printf '----------------------------------------------------------------------\n'
    printf '  Proceso objetivo : PID %s | PPID %s | Usuario: %s | Estado: %s\n' \
        "$raiz_pid" "$raiz_ppid" "$raiz_usr" "$raiz_est"
    printf '  Comando          : %s\n' "$raiz_cmd"
    printf '----------------------------------------------------------------------\n'
    printf '  Jerarquia detectada:\n'

    _recorrer_arbol_pid "$raiz_pid" "  " 1 0

    printf '----------------------------------------------------------------------\n'
    printf '  Evaluacion de impacto antes de detener:\n'
    printf '  * Descendientes detectados : %d proceso(s)' "$TOTAL_DESCENDIENTES"
    if ((TOTAL_DESCENDIENTES > 0)); then
        printf ' (profundidad maxima: %d nivel(es))' "$PROFUNDIDAD_MAX"
    fi
    printf '\n'
    printf '  * Estados sensibles        : %d en espera ininterrumpida (D), %d zombi(s) (Z)\n' \
        "$CONT_D" "$CONT_Z"
    if ((OTRO_USUARIO == 1)); then
        printf '  * Alcance de usuario       : incluye procesos de distintos usuarios\n'
    else
        printf '  * Alcance de usuario       : mismo usuario (%s)\n' "$raiz_usr"
    fi

    local riesgo="BAJO"
    local avisos=()

    if [[ "$raiz_pid" == "1" ]]; then
        riesgo="CRITICO"
        avisos+=("PID 1 es el proceso init/systemd principal del sistema.")
    fi

    local ancestro_actual="$$"
    while [[ -n "$ancestro_actual" && "$ancestro_actual" != "0" && -r "/proc/$ancestro_actual/stat" ]]; do
        if [[ "$ancestro_actual" == "$raiz_pid" ]]; then
            [[ "$riesgo" != "CRITICO" ]] && riesgo="ALTO"
            avisos+=("El PID %s forma parte de la cadena de la sesion/consola actual." "$raiz_pid")
            break
        fi
        local s_raw s_rest s_ppid
        s_raw=$(<"/proc/$ancestro_actual/stat") 2>/dev/null || break
        s_rest="${s_raw#*\) }"
        read -r _ s_ppid _ <<<"$s_rest"
        ancestro_actual="$s_ppid"
    done

    if ((CONT_D > 0)); then
        [[ "$riesgo" == "BAJO" ]] && riesgo="MEDIO-ALTO"
        avisos+=("Hay procesos en estado D (E/S); pueden tardar o no responder de inmediato.")
    fi

    if ((CONT_Z > 0)); then
        [[ "$riesgo" == "BAJO" ]] && riesgo="MEDIO"
        avisos+=("Existen procesos zombi (Z) en la rama; revisar padre/estado antes de actuar.")
    fi

    if ((TOTAL_DESCENDIENTES > 0)); then
        [[ "$riesgo" == "BAJO" ]] && riesgo="MEDIO"
        avisos+=("Detener el PID %s puede dejar %d descendiente(s) huerfano(s) (adoptados por PID 1)." \
            "$raiz_pid" "$TOTAL_DESCENDIENTES")
    fi

    if ((OTRO_USUARIO == 1)); then
        [[ "$riesgo" == "BAJO" ]] && riesgo="MEDIO"
        avisos+=("La jerarquia involucra mas de un usuario; verificar permisos y contexto.")
    fi

    printf '  * Riesgo orientativo       : %s\n' "$riesgo"
    if ((${#avisos[@]} > 0)); then
        for aviso in "${avisos[@]}"; do
            printf '    - %s\n' "$aviso"
        done
    else
        printf '    - Sin alertas adicionales ni descendientes dependientes.\n'
    fi
    printf '======================================================================\n'

    printf 'Presione Enter para regresar al menu...'
    read -r _
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    opcion_2
fi
