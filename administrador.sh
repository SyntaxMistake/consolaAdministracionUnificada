#!/usr/bin/env bash

menu_principal() {
    local opcion
    while true; do
        mostrar_encabezado
        echo -e "${BOLD}MENÚ PRINCIPAL DE OPCIONES:${RESET}\n"
        echo -e "  ${CYAN}[1]${RESET} Opción 1 - Filtro de procesos"
        echo -e "  ${CYAN}[2]${RESET} Opción 2 - Arbol completo de PID"
        echo -e "  ${CYAN}[3]${RESET} Opción 3 - Inspeccion de recursos de un PID"
        echo -e "  ${CYAN}[4]${RESET} Opcion 4 - Control de prioridad y senales"
	echo -e "  ${CYAN}[5]${RESET} Opcion 5 - Monitor en tiempo real"
        echo -e "  ${RED}[0]${RESET} Salir del aplicativo\n"
        echo -e "${CYAN}----------------------------------------------------------------------${RESET}"
        read -rp "Seleccione una opción [0-4]: " opcion

        case $opcion in
            1) opcion_1 ;;
            2) opcion_2 ;;
            3) opcion_3 ;;
            4) opcion_4 ;;
	    5) opcion_5 ;;
	    0)
                echo -e "\n${GREEN}Saliendo del sistema."
                exit 0
                ;;
            *)
                echo -e "\n${RED}[!] Opción inválida. Intente nuevamente.${RESET}"
                sleep 1.5
                ;;
        esac
    done
}

menu_principal
