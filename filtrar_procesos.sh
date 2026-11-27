#!/bin/bash
#Autor: Francesco
#Opción 1: Filtra procesos por usuario, estado o consumo
Filtrar_procesos(){

    clear
    echo "Filtrar Procesos"
    echo "1 Filtrar por usuario"
    echo "2 Filtrar por estado (R,S,D,Z)"
    echo "3 Filtrar por consume de CPU"
    echo
    read -p "Seleccione una opcion: " opcion
        case $opcion in
        1)
            # pedir usuario y filtrar
             read -p"Escriba el Usuario que desea buscar: " usuario
             ps -u "$usuario"
            ;;
        2)
            # pedir letra de estado y filtrar
            read -p"Ingrese la letra del estado para filtar" estado
            ps -eo pid,user,stat,comm | awk -v letra="$estado" 'NR==1 || $3 ~ "^" letra'
            ;;
        3)
            # mostrar procesos que más consumen
            ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -10
            ;;
        *)
            # opción inválida
            echo "Opcion no Valida"
            ;;
    esac
    read -p "Presione Enter para continuar..."
}
Filtrar_procesos
