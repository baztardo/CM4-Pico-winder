#!/bin/bash
# Interactive Board/MCU Selector
# Scans config folder and maps boards to MCU types

set -e

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../config" && pwd)"
BOARD_DB="$CONFIG_DIR/board_database.txt"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Default board database (can be extended)
create_default_board_db() {
    cat > "$BOARD_DB" <<'EOF'
# Board Database - Format: MCU_TYPE|BOARD_NAME|CONFIG_FILE|MANUFACTURER|NOTES
# MCU Types: STM32G0B1, RP2040, RP2350, STM32F103, etc.
# Config File: relative to config/ directory
# Manufacturer: BigTreeTech, Creality, Generic, Custom, etc.

# STM32G0B1 Boards
STM32G0B1|Manta M8P|generic-bigtreetech-manta-m8p-V1_1.cfg|BigTreeTech|Manta MP8 V1.1
STM32G0B1|Manta M4P|generic-bigtreetech-manta-m4p-v2.1.cfg|BigTreeTech|Manta MP4 V2.1
STM32G0B1|Generic STM32G0B1|generic-stm32g0b1.cfg|Generic|Generic STM32G0B1 board

# RP2040 Boards
RP2040|SKR Pico|generic-bigtreetech-skr-pico-v1.0.cfg|BigTreeTech|SKR Pico V1.0
RP2040|SKR Pico 2|generic-bigtreetech-skr-pico-v2.0.cfg|BigTreeTech|SKR Pico V2.0
RP2040|Generic RP2040|generic-rp2040.cfg|Generic|Generic RP2040 board
RP2040|Raspberry Pi Pico|generic-rpi-pico.cfg|Raspberry Pi|Raspberry Pi Pico

# RP2350 Boards
RP2350|SKR Pico 3|generic-bigtreetech-skr-pico-v3.0.cfg|BigTreeTech|SKR Pico V3.0 (RP2350)
RP2350|Generic RP2350|generic-rp2350.cfg|Generic|Generic RP2350 board

# STM32F103 Boards (common)
STM32F103|SKR Mini E3|generic-bigtreetech-skr-mini-e3-v1.2.cfg|BigTreeTech|SKR Mini E3 V1.2
STM32F103|SKR Mini E3 V2|generic-bigtreetech-skr-mini-e3-v2.0.cfg|BigTreeTech|SKR Mini E3 V2.0
STM32F103|Creality Ender 3|generic-creality-ender3.cfg|Creality|Ender 3 stock board
STM32F103|Generic STM32F103|generic-stm32f103.cfg|Generic|Generic STM32F103 board

# Add more boards below...
EOF
    echo "Created default board database at: $BOARD_DB"
}

# Scan config folder for .cfg files
scan_config_files() {
    echo -e "${BLUE}Scanning config folder...${NC}"
    local found=0
    while IFS= read -r cfg_file; do
        local basename=$(basename "$cfg_file")
        # Try to extract MCU type from config file
        local mcu_type=$(grep -i "^\[mcu" "$cfg_file" 2>/dev/null | head -1 | grep -oP "mcu\s*=\s*\K[^\s]+" || echo "UNKNOWN")
        # Try to extract board name from filename
        local board_name=$(echo "$basename" | sed 's/\.cfg$//' | sed 's/generic-//' | sed 's/-/ /g')
        
        if [ "$mcu_type" != "UNKNOWN" ]; then
            echo "Found: $basename -> MCU: $mcu_type"
            found=$((found + 1))
        fi
    done < <(find "$CONFIG_DIR" -maxdepth 1 -name "*.cfg" -type f 2>/dev/null)
    
    if [ $found -eq 0 ]; then
        echo -e "${YELLOW}No config files found with MCU info${NC}"
    fi
    return $found
}

# Interactive board selection
select_board_interactive() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Board/MCU Selection${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Load board database
    if [ ! -f "$BOARD_DB" ]; then
        echo -e "${YELLOW}Board database not found, creating default...${NC}"
        create_default_board_db
    fi
    
    # Group by MCU type
    echo -e "${GREEN}Available Boards:${NC}"
    echo ""
    
    local mcu_types=$(cut -d'|' -f1 "$BOARD_DB" | grep -v "^#" | grep -v "^$" | sort -u)
    local option_num=1
    declare -A options
    declare -A mcu_map
    declare -A config_map
    declare -A manufacturer_map
    
    # Build menu
    for mcu in $mcu_types; do
        echo -e "${BLUE}${mcu}:${NC}"
        while IFS='|' read -r mcu_type board_name config_file manufacturer notes; do
            if [ "$mcu_type" = "$mcu" ] && [ -n "$mcu_type" ] && [ "${mcu_type:0:1}" != "#" ]; then
                # Check if config file exists
                local config_path="$CONFIG_DIR/$config_file"
                local exists=""
                if [ -f "$config_path" ]; then
                    exists="${GREEN}✓${NC}"
                else
                    exists="${YELLOW}⚠${NC}"
                fi
                
                printf "  [%2d] %s %s - %s (%s)\n" "$option_num" "$exists" "$board_name" "$manufacturer" "$notes"
                options[$option_num]="$mcu_type"
                mcu_map[$option_num]="$mcu_type"
                config_map[$option_num]="$config_file"
                manufacturer_map[$option_num]="$manufacturer"
                option_num=$((option_num + 1))
            fi
        done < "$BOARD_DB"
        echo ""
    done
    
    # Add custom options
    echo -e "${YELLOW}Custom Options:${NC}"
    printf "  [%2d] %s Add custom board to database\n" "$option_num" "${BLUE}+${NC}"
    local custom_add=$option_num
    option_num=$((option_num + 1))
    
    printf "  [%2d] %s Scan config folder for boards\n" "$option_num" "${BLUE}🔍${NC}"
    local scan_option=$option_num
    option_num=$((option_num + 1))
    
    printf "  [%2d] %s Manual MCU selection (skip board)\n" "$option_num" "${BLUE}⚙${NC}"
    local manual_option=$option_num
    
    echo ""
    read -p "Select board [1-$option_num]: " selection
    
    if [ "$selection" = "$custom_add" ]; then
        add_custom_board
        return 1  # Restart selection
    elif [ "$selection" = "$scan_option" ]; then
        scan_config_files
        read -p "Press Enter to continue..."
        return 1  # Restart selection
    elif [ "$selection" = "$manual_option" ]; then
        manual_mcu_selection
        return 0
    elif [ -n "${options[$selection]}" ]; then
        SELECTED_MCU="${mcu_map[$selection]}"
        SELECTED_CONFIG="${config_map[$selection]}"
        SELECTED_MANUFACTURER="${manufacturer_map[$selection]}"
        echo ""
        echo -e "${GREEN}Selected:${NC}"
        echo "  MCU Type: $SELECTED_MCU"
        echo "  Config: $SELECTED_CONFIG"
        echo "  Manufacturer: $SELECTED_MANUFACTURER"
        return 0
    else
        echo -e "${RED}Invalid selection${NC}"
        return 1
    fi
}

# Add custom board to database
add_custom_board() {
    echo ""
    echo -e "${BLUE}Add Custom Board${NC}"
    echo ""
    read -p "MCU Type (e.g., STM32G0B1, RP2040): " mcu_type
    read -p "Board Name: " board_name
    read -p "Config File (relative to config/): " config_file
    read -p "Manufacturer: " manufacturer
    read -p "Notes: " notes
    
    # Add to database
    echo "$mcu_type|$board_name|$config_file|$manufacturer|$notes" >> "$BOARD_DB"
    echo ""
    echo -e "${GREEN}✓ Board added to database${NC}"
    echo "Edit $BOARD_DB to modify later"
    echo ""
}

# Manual MCU selection
manual_mcu_selection() {
    echo ""
    echo -e "${BLUE}Manual MCU Selection${NC}"
    echo ""
    echo "Common MCU Types:"
    echo "  1) STM32G0B1 (Manta MP8, etc.)"
    echo "  2) RP2040 (SKR Pico, Raspberry Pi Pico)"
    echo "  3) RP2350 (SKR Pico 3)"
    echo "  4) STM32F103 (SKR Mini E3, Creality boards)"
    echo "  5) Other (enter manually)"
    echo ""
    read -p "Select MCU [1-5]: " mcu_choice
    
    case $mcu_choice in
        1) SELECTED_MCU="STM32G0B1" ;;
        2) SELECTED_MCU="RP2040" ;;
        3) SELECTED_MCU="RP2350" ;;
        4) SELECTED_MCU="STM32F103" ;;
        5) 
            read -p "Enter MCU type: " SELECTED_MCU
            ;;
        *)
            SELECTED_MCU="STM32G0B1"  # Default
            ;;
    esac
    
    SELECTED_CONFIG=""
    SELECTED_MANUFACTURER="Custom"
    echo ""
    echo -e "${GREEN}Selected MCU: $SELECTED_MCU${NC}"
}

# Main
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Run as standalone script
    while true; do
        if select_board_interactive; then
            break
        fi
    done
    
    echo ""
    echo -e "${GREEN}Selection Complete!${NC}"
    echo "MCU Type: $SELECTED_MCU"
    [ -n "$SELECTED_CONFIG" ] && echo "Config File: $SELECTED_CONFIG"
    [ -n "$SELECTED_MANUFACTURER" ] && echo "Manufacturer: $SELECTED_MANUFACTURER"
fi

