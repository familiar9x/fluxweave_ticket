#!/bin/bash

###############################################################################
# Interactive Database Function/Procedure Tester
# Supports both PostgreSQL and Oracle
###############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

show_banner() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║          Database Function/Procedure Test Tool                 ║"
    echo "║                                                                ║"
    echo "║          PostgreSQL & Oracle Interactive Tester                ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_menu() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                      Select Database                          ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} PostgreSQL (jip-cp-ipa-postgre17)"
    echo -e "  ${GREEN}2)${NC} Oracle (jip-cp-ipa-oracle19c)"
    echo -e "  ${GREEN}3)${NC} Exit"
    echo ""
}

# PostgreSQL test function
test_postgres() {
    echo ""
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                    PostgreSQL Test                            ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Enter function name:${NC} )" func_name
    
    if [ -z "$func_name" ]; then
        echo -e "${RED}Function name cannot be empty${NC}"
        return
    fi
    
    echo ""
    echo -e "${YELLOW}Enter parameters (comma-separated, e.g., '001', 'USER001', '20250101')${NC}"
    echo -e "${YELLOW}Press Enter for no parameters:${NC}"
    read -p "> " params
    
    echo ""
    read -p "$(echo -e ${YELLOW}Is this a procedure? (y/n):${NC} )" is_proc
    
    # Build command
    CMD="./test_postgres_function.sh"
    
    if [ "$is_proc" = "y" ] || [ "$is_proc" = "Y" ]; then
        CMD="$CMD --procedure"
    fi
    
    CMD="$CMD $func_name"
    
    if [ -n "$params" ]; then
        # Split params and add them
        IFS=',' read -ra PARAM_ARRAY <<< "$params"
        for param in "${PARAM_ARRAY[@]}"; do
            # Trim whitespace
            param=$(echo "$param" | xargs)
            CMD="$CMD $param"
        done
    fi
    
    echo ""
    echo -e "${CYAN}Executing: $CMD${NC}"
    echo ""
    
    eval $CMD
}

# Oracle test function
test_oracle() {
    echo ""
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                      Oracle Test                              ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Enter function name:${NC} )" func_name
    
    if [ -z "$func_name" ]; then
        echo -e "${RED}Function name cannot be empty${NC}"
        return
    fi
    
    echo ""
    echo -e "${YELLOW}Enter parameters (comma-separated, e.g., '001', 'USER001', '20250101')${NC}"
    echo -e "${YELLOW}Note: Strings should be quoted like: \"'001'\", \"'USER001'\"${NC}"
    echo -e "${YELLOW}Press Enter for no parameters:${NC}"
    read -p "> " params
    
    echo ""
    read -p "$(echo -e ${YELLOW}Is this a procedure? (y/n):${NC} )" is_proc
    read -p "$(echo -e ${YELLOW}Use PL/SQL block? (y/n):${NC} )" use_block
    
    # Build command
    CMD="./test_oracle_function.sh"
    
    if [ "$is_proc" = "y" ] || [ "$is_proc" = "Y" ]; then
        CMD="$CMD --procedure"
    fi
    
    if [ "$use_block" = "y" ] || [ "$use_block" = "Y" ]; then
        CMD="$CMD --block"
    fi
    
    CMD="$CMD $func_name"
    
    if [ -n "$params" ]; then
        # Split params and add them
        IFS=',' read -ra PARAM_ARRAY <<< "$params"
        for param in "${PARAM_ARRAY[@]}"; do
            # Trim whitespace
            param=$(echo "$param" | xargs)
            CMD="$CMD \"$param\""
        done
    fi
    
    echo ""
    echo -e "${CYAN}Executing: $CMD${NC}"
    echo ""
    
    eval $CMD
}

# Main loop
main() {
    # Get script directory
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    cd "$SCRIPT_DIR"
    
    # Check if test scripts exist
    if [ ! -f "test_postgres_function.sh" ]; then
        echo -e "${RED}Error: test_postgres_function.sh not found${NC}"
        exit 1
    fi
    
    if [ ! -f "test_oracle_function.sh" ]; then
        echo -e "${RED}Error: test_oracle_function.sh not found${NC}"
        exit 1
    fi
    
    # Make scripts executable
    chmod +x test_postgres_function.sh
    chmod +x test_oracle_function.sh
    
    show_banner
    
    while true; do
        show_menu
        read -p "$(echo -e ${YELLOW}Enter your choice [1-3]:${NC} )" choice
        
        case $choice in
            1)
                test_postgres
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                test_oracle
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                echo ""
                echo -e "${GREEN}Goodbye!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please select 1-3.${NC}"
                sleep 1
                ;;
        esac
        
        clear
        show_banner
    done
}

# Run main
main
