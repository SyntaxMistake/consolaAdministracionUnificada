#!/usr/bin/env bash
# ==============================================================
# MODULO COMBINADO - REVISION DE ARCHIVOS Y AUDITORIA DE RED
# Proyecto No. 7 - Asistente Interactivo de Control y Auditoria
# Entorno: Ubuntu / WSL
# ==============================================================

VERSION_RED="2.0"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="$SCRIPT_DIR/reportes"

BOLD="${BOLD:-\033[1m}"
ROJO="${ROJO:-\033[1;31m}"
VERDE="${VERDE:-\033[1;32m}"
AMARILLO="${AMARILLO:-\033[1;33m}"
AZUL="${AZUL:-\033[1;34m}"
CYAN="${CYAN:-\033[1;36m}"
MAGENTA="${MAGENTA:-\033[1;35m}"
RESET="${RESET:-\033[0m}"

pausa_local() {
    echo
    read -r -p "Presiona ENTER para continuar..." _
}

# ---------- Validacion unificada de PID ----------
validar_pid() {
    local pid="$1"

    if [[ ! "$pid" =~ ^[0-9]+$ ]] || [ "$pid" -le 0 ]; then
        echo -e "${ROJO}Error: el PID debe ser un numero entero positivo.${RESET}"
        return 1
    fi

    if [ ! -d "/proc/$pid" ]; then
        echo -e "${ROJO}Error: no existe ningun proceso con PID $pid.${RESET}"
        return 1
    fi

    return 0
}

# ---------- Punto 4: Archivos abiertos por un proceso ----------
archivos_abiertos() {
    local pid="$1"
    local nombre dueno total

    nombre=$(ps -p "$pid" -o comm= 2>/dev/null | xargs || true)
    dueno=$(ps -p "$pid" -o user= 2>/dev/null | xargs || true)

    echo
    echo -e "${CYAN}==========================================${RESET}"
    echo -e "${BOLD}  ARCHIVOS ABIERTOS POR UN PROCESO${RESET}"
    echo -e "${CYAN}==========================================${RESET}"
    echo "Proceso : ${nombre:-Desconocido} (PID $pid)"
    echo "Usuario : ${dueno:-Desconocido}"
    echo "------------------------------------------"

    if [ -n "$dueno" ] && [ "$dueno" != "$(whoami)" ] && [ "$EUID" -ne 0 ]; then
        echo -e "${AMARILLO}Aviso: el proceso pertenece a '$dueno'. Sin sudo la lista puede salir incompleta o vacia.${RESET}"
        echo
    fi

    if command -v lsof >/dev/null 2>&1; then
        echo "[Metodo: lsof]"
        lsof -p "$pid" 2>/dev/null || echo -e "${AMARILLO}No se pudo leer toda la informacion (permisos insuficientes). Pruebe con sudo.${RESET}"
    else
        echo -e "${AMARILLO}lsof no esta instalado (instalelo con: sudo apt install lsof).${RESET}"
        echo "[Metodo alternativo: /proc/$pid/fd]"
        if ! ls -l "/proc/$pid/fd" 2>/dev/null; then
            echo -e "${ROJO}No se pudo leer /proc/$pid/fd (permisos insuficientes). Pruebe con sudo.${RESET}"
            return 1
        fi
    fi

    total=$(ls "/proc/$pid/fd" 2>/dev/null | wc -l)
    echo "------------------------------------------"
    echo "Total de descriptores de archivo abiertos: $total"
}

# ---------- Punto 5: Auditoria de conexiones de red por PID ----------
obtener_datos_proceso_red() {
    local pid="$1"
    PROC_NAME="$(ps -p "$pid" -o comm= 2>/dev/null | xargs || true)"
    PROC_USER="$(ps -p "$pid" -o user= 2>/dev/null | xargs || true)"
    PROC_STATE="$(ps -p "$pid" -o stat= 2>/dev/null | xargs || true)"
    PROC_CMD="$(ps -p "$pid" -o args= 2>/dev/null | head -c 240 || true)"
    PROC_EXE="$(readlink -f "/proc/$pid/exe" 2>/dev/null || echo "No disponible")"
    [[ -n "$PROC_NAME" ]] || PROC_NAME="Desconocido"
    [[ -n "$PROC_USER" ]] || PROC_USER="Desconocido"
    [[ -n "$PROC_STATE" ]] || PROC_STATE="Desconocido"
    [[ -n "$PROC_CMD" ]] || PROC_CMD="No disponible"
}

auditar_red_pid() {
    local pid="$1"

    if ! command -v ss >/dev/null 2>&1; then
        echo -e "${ROJO}[ERROR] Falta 'ss' (iproute2). Instala con: sudo apt update && sudo apt install iproute2${RESET}"
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${ROJO}[ERROR] Falta 'python3'. Instala con: sudo apt update && sudo apt install python3${RESET}"
        return 1
    fi

    mkdir -p "$REPORT_DIR"

    local marca raw base
    marca="$(date '+%Y%m%d_%H%M%S')"
    raw="$(mktemp)"
    base="$REPORT_DIR/auditoria_${pid}_${marca}"

    obtener_datos_proceso_red "$pid"

    ss -H -tunap 2>/dev/null | awk -v patron="pid='"$pid"', " 'index($0, patron) {print}' > "$raw" || true

    echo
    echo -e "${AZUL}┌─ RESUMEN DEL PROCESO AUDITADO (RED) ─────────────────────────┐${RESET}"
    printf "  Nombre:       %s\n" "$PROC_NAME"
    printf "  Usuario:      %s\n" "$PROC_USER"
    printf "  PID:          %s\n" "$pid"
    printf "  Estado:       %s\n" "$PROC_STATE"
    printf "  Ejecutable:   %s\n" "$PROC_EXE"
    printf "  Comando:      %s\n" "$PROC_CMD"
    echo -e "${AZUL}└─────────────────────────────────────────────────────────────┘${RESET}"

    if [[ ! -s "$raw" ]]; then
        echo -e "${AMARILLO}[AVISO] ss no encontro sockets asociados a este PID.${RESET}"
        echo "Puede que el proceso no tenga conexiones, o que WSL/permisos no permitan verlas."
        echo "Prueba ejecutar el asistente con: sudo ./administrador.sh"
        rm -f "$raw"
        return 0
    fi

    python3 - "$pid" "$raw" "$base" "$PROC_NAME" "$PROC_USER" "$PROC_STATE" "$PROC_EXE" "$PROC_CMD" <<'PY'
import sys, json, socket, ipaddress
from datetime import datetime

pid, raw_file, base, name, user, proc_state, exe, cmd = sys.argv[1:]
with open(raw_file, encoding="utf-8", errors="replace") as f:
    lines = [x.strip() for x in f if x.strip()]

def endpoint(value):
    value = value.strip()
    if value.startswith("[") and "]:" in value:
        host, port = value[1:].rsplit("]:", 1)
    elif ":" in value:
        host, port = value.rsplit(":", 1)
    else:
        return value, "?", value
    return host, port, value

def ip_kind(host):
    if host in ("*", "0.0.0.0", "::", "[::]"):
        return "TODAS LAS INTERFACES"
    try:
        ip = ipaddress.ip_address(host.split("%")[0])
        if ip.is_loopback:
            return "LOOPBACK"
        if ip.is_private:
            return "PRIVADA"
        if ip.is_link_local:
            return "LINK-LOCAL"
        if ip.is_multicast:
            return "MULTICAST"
        return "PUBLICA"
    except ValueError:
        return "NOMBRE/NO IP"

def service(port, proto):
    try:
        return socket.getservbyport(int(port), proto.lower())
    except Exception:
        return "sin nombre"

def state_label(s):
    return {
        "LISTEN": "ESCUCHA",
        "ESTAB": "ESTABLECIDA",
        "ESTABLISHED": "ESTABLECIDA",
        "UNCONN": "SIN CONEXION",
        "CLOSE-WAIT": "CLOSE-WAIT",
        "TIME-WAIT": "TIME-WAIT",
        "SYN-SENT": "SYN-SENT",
        "SYN-RECV": "SYN-RECV",
    }.get(s.upper(), s.upper())

records = []
for line in lines:
    parts = line.split()
    if len(parts) < 6:
        continue
    proto, state, local, peer = parts[0], parts[1], parts[4], parts[5]
    lhost, lport, _ = endpoint(local)
    rhost, rport, _ = endpoint(peer)
    proto_name = "TCP" if proto.lower().startswith("tcp") else "UDP"
    lkind = ip_kind(lhost)
    rkind = ip_kind(rhost)
    alerts = []
    if state.upper() == "LISTEN" and lkind == "TODAS LAS INTERFACES":
        alerts.append("ESCUCHA EXPUESTA")
    if rkind == "PUBLICA" and rhost not in ("*", "0.0.0.0", "::"):
        alerts.append("DESTINO PUBLICO")
    if lport.isdigit() and int(lport) not in (20,21,22,23,25,53,80,110,123,143,443,445,3306,5432,6379,8080,8443,27017):
        if state.upper() == "LISTEN":
            alerts.append("PUERTO NO COMUN")
    records.append({
        "protocolo": proto_name, "estado": state_label(state),
        "ip_local": lhost, "puerto_local": lport,
        "servicio": service(lport, proto_name),
        "clasificacion_local": lkind,
        "ip_remota": rhost, "puerto_remoto": rport,
        "clasificacion_remota": rkind, "alertas": alerts,
        "linea_ss": line
    })

listen = sum(1 for r in records if r["estado"] == "ESCUCHA")
established = sum(1 for r in records if r["estado"] == "ESTABLECIDA")
udp = sum(1 for r in records if r["protocolo"] == "UDP")
tcp = sum(1 for r in records if r["protocolo"] == "TCP")
alerts = [r for r in records if r["alertas"]]
now = datetime.now().astimezone().isoformat(timespec="seconds")

print("\n╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗")
print("║                                      RESULTADOS DE LA AUDITORIA DE RED                                               ║")
print("╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝")
print(f"Fecha: {now} | PID: {pid} | Proceso: {name} | Usuario: {user}")
print(f"Total sockets: {len(records)} | TCP: {tcp} | UDP: {udp} | En escucha: {listen} | Establecidas: {established}")
print("-" * 118)
print(f"{'PROTO':<6} {'ESTADO':<15} {'IP LOCAL':<25} {'PUERTO':<8} {'SERVICIO':<14} {'IP REMOTA':<25} {'P.REM':<7}")
print("-" * 118)
for r in records:
    print(f"{r['protocolo']:<6} {r['estado']:<15} {r['ip_local'][:24]:<25} {r['puerto_local']:<8} {r['servicio'][:13]:<14} {r['ip_remota'][:24]:<25} {r['puerto_remoto']:<7}")
    if r["alertas"]:
        print("       !! ALERTA: " + ", ".join(r["alertas"]))
print("-" * 118)

print("\nANALISIS Y ALERTAS")
if not alerts:
    print("[OK] No se detectaron condiciones de alerta segun las reglas basicas.")
for r in alerts:
    print(f"[ALERTA] {r['protocolo']} {r['ip_local']}:{r['puerto_local']} -> {r['ip_remota']}:{r['puerto_remoto']} | {', '.join(r['alertas'])}")

print("\nCRITERIOS DE INTERPRETACION")
print("- 0.0.0.0 o :: en LISTEN: el servicio escucha en todas las interfaces disponibles.")
print("- 127.0.0.1 o ::1: servicio limitado al equipo local (loopback).")
print("- IP privada: direccion de red local; IP publica: destino enrutable publicamente.")
print("- Una alerta es una senal para revisar, no una prueba de actividad maliciosa.")

report = {
    "auditoria": {
        "fecha": now, "pid": int(pid), "proceso": name, "usuario": user,
        "estado_proceso": proc_state, "ejecutable": exe, "comando": cmd,
        "totales": {"sockets": len(records), "tcp": tcp, "udp": udp,
                    "escucha": listen, "establecidas": established,
                    "alertas": len(alerts)}
    },
    "conexiones": records,
    "nota": "Las alertas son heuristicas y requieren revision manual."
}
with open(base + ".json", "w", encoding="utf-8") as f:
    json.dump(report, f, indent=2, ensure_ascii=False)

with open(base + ".txt", "w", encoding="utf-8") as f:
    f.write("AUDITORIA DE CONEXIONES DE RED\n")
    f.write(f"Fecha: {now}\nPID: {pid}\nProceso: {name}\nUsuario: {user}\n")
    f.write(f"Ejecutable: {exe}\nComando: {cmd}\n")
    f.write(f"Totales: sockets={len(records)}, TCP={tcp}, UDP={udp}, LISTEN={listen}, ESTABLISHED={established}\n\n")
    for i, r in enumerate(records, 1):
        f.write(f"{i}. {r['protocolo']} {r['estado']} {r['ip_local']}:{r['puerto_local']} ({r['servicio']}) -> {r['ip_remota']}:{r['puerto_remoto']}\n")
        if r["alertas"]:
            f.write("   ALERTAS: " + ", ".join(r["alertas"]) + "\n")
    f.write("\nNota: las alertas son heuristicas y no confirman actividad maliciosa.\n")
print(f"\n[EXPORTADO] TXT : {base}.txt")
print(f"[EXPORTADO] JSON: {base}.json")
PY
    rm -f "$raw"
}

# ---------- Subflujo de la Opcion 3 ----------
ejecutar_inspeccion_recursos() {
    local pid modo

    echo
    echo -e "${CYAN}======================================================================${RESET}"
    echo -e "${BOLD}  INSPECCION DE RECURSOS DE UN PID (ARCHIVOS Y RED)${RESET}"
    echo -e "${CYAN}======================================================================${RESET}"
    read -rp "Ingrese el PID del proceso: " pid

    validar_pid "$pid" || return 1

    echo
    echo "Que desea revisar para el PID $pid?"
    echo "  [1] Archivos abiertos"
    echo "  [2] Conexiones de red y puertos"
    echo "  [3] Ambos (archivos abiertos + conexiones de red)"
    echo "  [0] Cancelar y volver"
    read -rp "Seleccione una opcion [0-3]: " modo

    case "$modo" in
        1) archivos_abiertos "$pid" ;;
        2) auditar_red_pid "$pid" ;;
        3)
            archivos_abiertos "$pid"
            auditar_red_pid "$pid"
            ;;
        0) return 0 ;;
        *)
            echo -e "${ROJO}[!] Opcion invalida.${RESET}"
            return 1
            ;;
    esac
}

ejecutar_inspeccion_recursos