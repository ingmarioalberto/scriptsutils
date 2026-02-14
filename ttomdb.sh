#!/bin/bash

# Colores para mejorar la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración
CONFIG_DIR="$HOME/.config/ttomdb"
API_KEY_FILE="$CONFIG_DIR/api.key"
OMDB_API="http://www.omdbapi.com"

# Función para mostrar ayuda
show_help() {
    echo -e "${YELLOW}Uso: $0 [opciones] IMDB_ID${NC}"
    echo "Opciones:"
    echo "  -h, --help     Muestra esta ayuda"
    echo "  -j, --json     Muestra la respuesta JSON original (por defecto)"
    echo "  -t, --text     Convierte la respuesta a formato texto plano"
    echo
    echo "Ejemplos:"
    echo "  $0 tt3896198                    # Muestra JSON de Guardians of the Galaxy Vol. 2"
    echo "  $0 -t tt0111161                  # Muestra en texto plano The Shawshank Redemption"
    echo "  $0 --text tt0468569               # Muestra en texto plano The Dark Knight"
    echo
    echo "Nota: La API key debe estar en: $API_KEY_FILE"
}

# Función para leer API key
read_api_key() {
    if [ ! -f "$API_KEY_FILE" ]; then
        echo -e "${RED}Error: No se encontró el archivo de API key${NC}" >&2
        echo -e "Por favor, crea el archivo: $API_KEY_FILE" >&2
        echo -e "Y agrega tu API key de OMDb (https://www.omdbapi.com/apikey.aspx)" >&2
        exit 1
    fi
    
    API_KEY=$(cat "$API_KEY_FILE" | tr -d '\n\r ')
    
    if [ -z "$API_KEY" ]; then
        echo -e "${RED}Error: El archivo de API key está vacío${NC}" >&2
        exit 1
    fi
}

# Función para convertir JSON a texto plano
convert_to_text() {
    local json="$1"
    
    # Verificar si la respuesta es válida
    local response=$(echo "$json" | jq -r '.Response // "False"')
    
    if [ "$response" = "False" ]; then
        local error=$(echo "$json" | jq -r '.Error // "Unknown error"')
        echo -e "${RED}Error de OMDb: $error${NC}"
        return 1
    fi
    
    # Extraer campos principales
    local title=$(echo "$json" | jq -r '.Title // "N/A"')
    local year=$(echo "$json" | jq -r '.Year // "N/A"')
    local rated=$(echo "$json" | jq -r '.Rated // "N/A"')
    local released=$(echo "$json" | jq -r '.Released // "N/A"')
    local runtime=$(echo "$json" | jq -r '.Runtime // "N/A"')
    local genre=$(echo "$json" | jq -r '.Genre // "N/A"')
    local director=$(echo "$json" | jq -r '.Director // "N/A"')
    local writer=$(echo "$json" | jq -r '.Writer // "N/A"')
    local actors=$(echo "$json" | jq -r '.Actors // "N/A"')
    local plot=$(echo "$json" | jq -r '.Plot // "N/A"')
    local language=$(echo "$json" | jq -r '.Language // "N/A"')
    local country=$(echo "$json" | jq -r '.Country // "N/A"')
    local awards=$(echo "$json" | jq -r '.Awards // "N/A"')
    local poster=$(echo "$json" | jq -r '.Poster // "N/A"')
    local metascore=$(echo "$json" | jq -r '.Metascore // "N/A"')
    local imdb_rating=$(echo "$json" | jq -r '.imdbRating // "N/A"')
    local imdb_votes=$(echo "$json" | jq -r '.imdbVotes // "N/A"')
    local imdb_id=$(echo "$json" | jq -r '.imdbID // "N/A"')
    local type=$(echo "$json" | jq -r '.Type // "N/A"')
    local dvd=$(echo "$json" | jq -r '.DVD // "N/A"')
    local box_office=$(echo "$json" | jq -r '.BoxOffice // "N/A"')
    local production=$(echo "$json" | jq -r '.Production // "N/A"')
    local website=$(echo "$json" | jq -r '.Website // "N/A"')
    
    # Mostrar en formato texto plano
    echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Título:${NC} $title"
    echo -e "${BLUE}Año:${NC} $year"
    echo -e "${PURPLE}Tipo:${NC} $type"
    echo -e "${CYAN}ID IMDb:${NC} $imdb_id"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Clasificación:${NC} $rated"
    echo -e "${BLUE}Estreno:${NC} $released"
    echo -e "${PURPLE}Duración:${NC} $runtime"
    echo -e "${CYAN}Género:${NC} $genre"
    echo -e "${YELLOW}Director:${NC} $director"
    echo -e "${GREEN}Guionista(s):${NC} $writer"
    echo -e "${BLUE}Actores:${NC} $actors"
    echo -e "${PURPLE}Idioma:${NC} $language"
    echo -e "${CYAN}País:${NC} $country"
    echo -e "${YELLOW}Premios:${NC} $awards"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
    
    # Mostrar ratings
    echo -e "${GREEN}Calificaciones:${NC}"
    echo "$json" | jq -c '.Ratings // []' | jq -r '.[] | "  • \(.Source): \(.Value)"' | while read -r rating; do
        echo -e "$rating"
    done
    
    # Ratings individuales
    local imdb_rating_display=$(echo "$json" | jq -r '.imdbRating // "N/A"')
    local imdb_votes_display=$(echo "$json" | jq -r '.imdbVotes // "N/A"')
    local metascore_display=$(echo "$json" | jq -r '.Metascore // "N/A"')
    
    [ "$imdb_rating_display" != "N/A" ] && [ "$imdb_rating_display" != "null" ] && echo -e "${BLUE}  • IMDb Rating:${NC} $imdb_rating_display/10 ($imdb_votes_display votos)"
    [ "$metascore_display" != "N/A" ] && [ "$metascore_display" != "null" ] && echo -e "${PURPLE}  • Metascore:${NC} $metascore_display"
    
    echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Sinopsis:${NC} $plot"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
    
    # Información adicional
    [ "$dvd" != "N/A" ] && [ "$dvd" != "null" ] && echo -e "${GREEN}Lanzamiento DVD:${NC} $dvd"
    [ "$box_office" != "N/A" ] && [ "$box_office" != "null" ] && echo -e "${BLUE}Taquilla:${NC} $box_office"
    [ "$production" != "N/A" ] && [ "$production" != "null" ] && echo -e "${PURPLE}Producción:${NC} $production"
    [ "$website" != "N/A" ] && [ "$website" != "null" ] && echo -e "${CYAN}Sitio web:${NC} $website"
    [ "$poster" != "N/A" ] && [ "$poster" != "null" ] && echo -e "${YELLOW}Póster:${NC} $poster"
    
    echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
}

# Función principal para consultar OMDb
query_omdb() {
    local imdb_id="$1"
    local output_format="$2"
    
    # Validar formato de ID
    if [[ ! "$imdb_id" =~ ^tt[0-9]+$ ]]; then
        echo -e "${RED}Error: El ID debe tener formato ttXXXXXX (ej: tt0111161)${NC}" >&2
        return 1
    fi
    
    # Construir URL de consulta
    local url="${OMDB_API}/?i=${imdb_id}&apikey=${API_KEY}"
    
    # Hacer la consulta
    echo -e "${CYAN}Consultando OMDb para ID: $imdb_id${NC}" >&2
    local json_response=$(curl -s "$url")
    
    # Verificar si la respuesta es válida
    if [ -z "$json_response" ]; then
        echo -e "${RED}Error: No se recibió respuesta de OMDb${NC}" >&2
        return 1
    fi
    
    # Verificar si hay error (API key inválida, etc)
    local error_check=$(echo "$json_response" | jq -r '.Error // ""')
    if [ ! -z "$error_check" ] && [ "$error_check" != "null" ]; then
        echo -e "${RED}Error de OMDb: $error_check${NC}" >&2
        return 1
    fi
    
    # Procesar según el formato solicitado
    case "$output_format" in
        json)
            # JSON con ratings aplanados
            jq --help 2>/dev/null 1>/dev/null && echo "$json_response" | jq || echo "$json_response"
            ;;
        text)
            # Convertir a texto plano
            convert_to_text "$json_response"
            ;;
    esac
}

# Función principal
main() {
    # Verificar dependencias
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: curl no está instalado. Por favor, instálalo primero.${NC}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq no está instalado. Por favor, instálalo primero.${NC}"
        echo -e "En Ubuntu/Debian: sudo apt-get install jq"
        echo -e "En macOS: brew install jq"
        exit 1
    fi
    
    # Leer API key
    read_api_key
    
    # Variables por defecto
    local output_format="json"  # json es el default
    
    # Procesar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -j|--json)
                output_format="json"
                shift
                ;;
            -t|--text)
                output_format="text"
                shift
                ;;
            *)
                imdb_id="$1"
                shift
                ;;
        esac
    done
    
    # Verificar que hay ID
    if [ -z "$imdb_id" ]; then
        echo -e "${RED}Error: Debes especificar un ID de IMDb${NC}"
        show_help
        exit 1
    fi
    
    # Realizar consulta
    query_omdb "$imdb_id" "$output_format"
}

# Ejecutar función principal
main "$@"
