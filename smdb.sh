#!/bin/bash

# Colores para mejorar la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para mostrar ayuda
show_help() {
    echo -e "${YELLOW}Uso: $0 [opciones] \"nombre de la película/serie\"${NC}"
    echo "Opciones:"
    echo "  -h, --help           Muestra esta ayuda"
    echo "  -a, --all            Muestra todos los resultados encontrados"
    echo "  -n, --num-results N  Número de resultados a mostrar (por defecto: 1)"
    echo "  -t, --type TIPO      Filtrar por tipo (movie, tvSeries, video, short, feature)"
    echo "  -y, --year AÑO        Filtrar por año exacto"
    echo "  -y, --year AÑO1-AÑO2  Filtrar por rango de años (ej: 2000-2010)"
    echo "  -j, --json           Muestra el JSON raw (para depuración)"
    echo
    echo "Ejemplos:"
    echo "  $0 \"The Matrix\""
    echo "  $0 -a \"two and a half\""
    echo "  $0 -n 3 -t tvSeries \"star wars\""
    echo "  $0 -y 1999 \"the matrix\"           # Solo películas de 1999"
    echo "  $0 -y 2000-2010 \"batman\"          # Películas entre 2000 y 2010"
    echo "  $0 -j \"inception\""
}

# Función para URL-encode
urlencode() {
    local string="$1"
    local encoded=""
    local pos=0
    local c
    local o
    
    while [ $pos -lt ${#string} ]; do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="$c" ;;
            * ) printf -v o '%%%02X' "'$c" ;;
        esac
        encoded+="$o"
        pos=$((pos + 1))
    done
    echo "$encoded"
}

# Función para verificar si un año coincide con el filtro
check_year_filter() {
    local item_year="$1"
    local year_filter="$2"
    
    # Si no hay filtro, todo coincide
    if [ -z "$year_filter" ]; then
        return 0
    fi
    
    # Si el item no tiene año, no coincide
    if [ -z "$item_year" ] || [ "$item_year" = "null" ]; then
        return 1
    fi
    
    # Verificar si es un rango (contiene guión)
    if [[ "$year_filter" == *"-"* ]]; then
        local start_year=$(echo "$year_filter" | cut -d'-' -f1)
        local end_year=$(echo "$year_filter" | cut -d'-' -f2)
        
        # Si es un número, comparar directamente
        if [[ "$item_year" =~ ^[0-9]+$ ]]; then
            if [ "$item_year" -ge "$start_year" ] && [ "$item_year" -le "$end_year" ]; then
                return 0
            fi
        fi
    else
        # Filtro de año exacto
        if [ "$item_year" = "$year_filter" ]; then
            return 0
        fi
    fi
    
    return 1
}

# Función para buscar en IMDb usando el endpoint de sugerencias
search_imdb_json() {
    local query="$1"
    local show_all="$2"
    local num_results="$3"
    local filter_type="$4"
    local year_filter="$5"
    local show_json="$6"
    
    # Codificar la consulta para URL
    local encoded_query=$(urlencode "$query")
    
    # Construir URL del endpoint
    local api_url="https://v3.sg.media-imdb.com/suggestion/x/${encoded_query}.json?includeVideos"
    
    echo -e "${CYAN}Buscando: $query${NC}" >&2
    
    # Hacer la petición curl
    local json_response=$(curl -s -L -A "Mozilla/5.0" "$api_url")
    
    # Verificar si la respuesta es válida
    if [ -z "$json_response" ] || [ "$json_response" = "{}" ]; then
        echo -e "${RED}No se recibieron datos de IMDb${NC}" >&2
        return 1
    fi
    
    # Si se solicita JSON raw, mostrarlo y salir
    if [ "$show_json" = "true" ]; then
        echo "$json_response" | jq '.' 2>/dev/null || echo "$json_response"
        return 0
    fi
    
    # Verificar si hay resultados
    local total_results=$(echo "$json_response" | jq '.d | length' 2>/dev/null)
    
    if [ -z "$total_results" ] || [ "$total_results" = "0" ] || [ "$total_results" = "null" ]; then
        echo -e "${RED}No se encontraron resultados para: $query${NC}" >&2
        return 1
    fi
    
    echo -e "${GREEN}Se encontraron $total_results resultados${NC}" >&2
    echo >&2
    
    # Procesar y mostrar resultados
    local count=0
    local index=0
    local filtered_count=0
    local year_filter_active=false
    
    if [ ! -z "$year_filter" ]; then
        year_filter_active=true
        echo -e "${YELLOW}Filtrando por año: $year_filter${NC}" >&2
    fi
    
    # Usar jq para procesar JSON si está disponible
    if command -v jq &> /dev/null; then
        while [ $count -lt $num_results ] && [ $index -lt $total_results ]; do
            # Obtener el elemento actual
            local item=$(echo "$json_response" | jq -c ".d[$index]")
            local item_type=$(echo "$item" | jq -r '.qid // "unknown"')
            
            # Obtener el año (puede ser simple o rango para series)
            local item_year=$(echo "$item" | jq -r '.y // ""')
            local item_year_range=$(echo "$item" | jq -r '.yr // ""')
            
            # Aplicar filtro por tipo
            if [ ! -z "$filter_type" ] && [ "$filter_type" != "$item_type" ]; then
                index=$((index + 1))
                continue
            fi
            
            # Aplicar filtro por año
            if [ "$year_filter_active" = true ]; then
                local year_match=false
                
                # Probar con año simple
                if check_year_filter "$item_year" "$year_filter"; then
                    year_match=true
                fi
                
                # Para series, probar con el año de inicio del rango
                if [ "$year_match" = false ] && [ ! -z "$item_year_range" ]; then
                    local range_start=$(echo "$item_year_range" | cut -d'-' -f1)
                    if check_year_filter "$range_start" "$year_filter"; then
                        year_match=true
                    fi
                fi
                
                if [ "$year_match" = false ]; then
                    index=$((index + 1))
                    filtered_count=$((filtered_count + 1))
                    continue
                fi
            fi
            
            # Extraer información
            local id=$(echo "$item" | jq -r '.id // "N/A"')
            local title=$(echo "$item" | jq -r '.l // "N/A"')
            local year=$(echo "$item" | jq -r '.y // ""')
            local end_year=$(echo "$item" | jq -r '.yr // ""' | cut -d'-' -f2)
            local cast=$(echo "$item" | jq -r '.s // "N/A"')
            local image_url=$(echo "$item" | jq -r '.i.imageUrl // ""')
            local type_display=$(echo "$item" | jq -r '.qid // "unknown"' | tr '[:lower:]' '[:upper:]')
            local rank=$(echo "$item" | jq -r '.rank // "N/A"')
            
            # Determinar rango de años para series
            local year_display="$year"
            if [ ! -z "$end_year" ] && [ "$end_year" != "$year" ] && [ "$end_year" != "null" ]; then
                year_display="$year-$end_year"
            fi
            
            # Mostrar información
            echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
            echo -e "${GREEN}Título:${NC} $title"
            echo -e "${BLUE}ID:${NC} $id"
            echo -e "${PURPLE}Tipo:${NC} $type_display"
            [ ! -z "$year_display" ] && echo -e "${CYAN}Año(s):${NC} $year_display"
            [ "$rank" != "N/A" ] && echo -e "${YELLOW}Ranking:${NC} $rank"
            echo -e "${GREEN}Reparto/Descripción:${NC} $cast"
            [ ! -z "$image_url" ] && echo -e "${BLUE}Imagen:${NC} $image_url"
            
            count=$((count + 1))
            index=$((index + 1))
        done
    else
        # Fallback sin jq - versión simplificada
        echo -e "${YELLOW}Nota: Para mejores resultados, instala 'jq' (procesador JSON)${NC}" >&2
        echo "$json_response" | grep -o '"d":\[[^]]*\]' | sed 's/"d"://' | tr '}' '\n' | while read -r item; do
            if [ $count -ge $num_results ]; then
                break
            fi
            
            if [[ $item == *"\"l\":"* ]]; then
                local title=$(echo "$item" | grep -o '"l":"[^"]*"' | sed 's/"l":"//;s/"//g')
                local id=$(echo "$item" | grep -o '"id":"[^"]*"' | sed 's/"id":"//;s/"//g')
                local year=$(echo "$item" | grep -o '"y":[0-9]*' | sed 's/"y"://')
                local cast=$(echo "$item" | grep -o '"s":"[^"]*"' | sed 's/"s":"//;s/"//g')
                
                # Filtro básico de año para fallback (solo exacto)
                if [ "$year_filter_active" = true ] && [ ! -z "$year" ]; then
                    if [[ "$year_filter" != "$year" ]]; then
                        continue
                    fi
                fi
                
                echo -e "${YELLOW}════════════════════════════════════════════${NC}"
                echo -e "${GREEN}Título:${NC} $title"
                echo -e "${BLUE}ID:${NC} $id"
                [ ! -z "$year" ] && echo -e "${CYAN}Año:${NC} $year"
                [ ! -z "$cast" ] && echo -e "${YELLOW}Reparto:${NC} $cast"
                
                count=$((count + 1))
            fi
        done
    fi
    
    if [ "$year_filter_active" = true ] && [ $count -eq 0 ]; then
        echo -e "${RED}No se encontraron resultados que coincidan con el filtro de año: $year_filter${NC}" >&2
    fi
    
    echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
}

# Función principal
main() {
    # Verificar dependencias
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: curl no está instalado. Por favor, instálalo primero.${NC}"
        exit 1
    fi
    
    # Variables por defecto
    local show_all=false
    local num_results=1
    local filter_type=""
    local year_filter=""
    local show_json=false
    
    # Procesar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -a|--all)
                show_all=true
                shift
                ;;
            -n|--num-results)
                num_results="$2"
                shift 2
                ;;
            -t|--type)
                filter_type="$2"
                shift 2
                ;;
            -y|--year)
                year_filter="$2"
                shift 2
                ;;
            -j|--json)
                show_json=true
                shift
                ;;
            *)
                query="$1"
                shift
                ;;
        esac
    done
    
    # Verificar que hay consulta
    if [ -z "$query" ]; then
        echo -e "${RED}Error: Debes especificar un término de búsqueda${NC}"
        show_help
        exit 1
    fi
    
    # Si show_all es true, mostrar hasta 10 resultados
    if [ "$show_all" = true ]; then
        num_results=10
    fi
    
    # Validar formato del filtro de año
    if [ ! -z "$year_filter" ]; then
        if [[ "$year_filter" =~ ^[0-9]{4}$ ]]; then
            # Año exacto - válido
            :
        elif [[ "$year_filter" =~ ^[0-9]{4}-[0-9]{4}$ ]]; then
            # Rango de años - válido
            local start_year=$(echo "$year_filter" | cut -d'-' -f1)
            local end_year=$(echo "$year_filter" | cut -d'-' -f2)
            if [ "$start_year" -gt "$end_year" ]; then
                echo -e "${RED}Error: El año inicial no puede ser mayor que el año final${NC}"
                exit 1
            fi
        else
            echo -e "${RED}Error: Formato de año inválido. Usa YYYY o YYYY-YYYY${NC}"
            exit 1
        fi
    fi
    
    # Realizar búsqueda
    search_imdb_json "$query" "$show_all" "$num_results" "$filter_type" "$year_filter" "$show_json"
}

# Ejecutar función principal
main "$@"
