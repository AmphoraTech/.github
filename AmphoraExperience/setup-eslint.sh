#!/usr/bin/env bash
set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Source the core amphora setup functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/setup-amphora.sh" ]; then
    source "$SCRIPT_DIR/setup-amphora.sh"
else
    echo "ERROR: setup-amphora.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Ensure jq is available for JSON manipulation
require_cmd jq

# Install ESLint dependencies
install_eslint_dependencies() {
    if [ -d "$ESLINT_STANDARDS_DIR" ]; then
        echo "Installing ESLint dependencies..."
        cd "$ESLINT_STANDARDS_DIR"

        if [ -f "package.json" ]; then
            echo "Running npm install in $ESLINT_STANDARDS_DIR"
            npm install
            echo "ESLint dependencies installed"
        else
            echo "Warning: No package.json found in $ESLINT_STANDARDS_DIR"
        fi

        cd "$ROOT_STANDARDS_DIR"
    else
        echo "ESLint directory not found: $ESLINT_STANDARDS_DIR"
        exit 1
    fi
}

# Check if extension is installed
is_extension_installed() {
    local editor_cmd="$1"
    local extension_id="$2"
    local installed_extensions
    
    installed_extensions=$($editor_cmd --list-extensions 2>/dev/null || echo "")
    echo "$installed_extensions" | grep -q "^${extension_id}$"
}

# Install extensions globally
install_global_extensions() {
    local editor_cmd="$1"
    local editor_name="$2"
    
    # Essential ESLint extensions
    local extensions=(
        "dbaeumer.vscode-eslint"
        "ms-vscode.vscode-typescript-next"
        "Vue.volar"
        "bradlc.vscode-tailwindcss"
        "christian-kohler.path-intellisense"
    )

    echo -e "${BLUE}Installing global $editor_name extensions${NC}"

    if ! command -v "$editor_cmd" &>/dev/null; then
        echo -e "${YELLOW}$editor_name CLI not available - install extensions manually${NC}"
        echo "Extensions to install:"
        for ext in "${extensions[@]}"; do
            echo "  - $ext"
        done
        return 0
    fi

    local installed=0 skipped=0 failed=0

    for extension in "${extensions[@]}"; do
        if is_extension_installed "$editor_cmd" "$extension"; then
            echo "  Already installed: $extension"
            ((skipped++))
        else
            echo "  Installing: $extension"
            if $editor_cmd --install-extension "$extension" --force >/dev/null 2>&1; then
                echo "    Success: $extension"
                ((installed++))
            else
                echo "    Failed: $extension"
                ((failed++))
            fi
        fi
    done

    echo -e "${GREEN}Extension summary:${NC}"
    echo "  Installed: $installed"
    echo "  Skipped: $skipped"
    [ $failed -gt 0 ] && echo -e "${RED}  Failed: $failed${NC}"
}

# Parse command line arguments
parse_arguments() {
    GLOBAL_FLAG=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --global)
                GLOBAL_FLAG=true
                shift
                ;;
            *)
                echo "Usage: $0 [--global]"
                echo "  --global  Install extensions globally in VSCode/Cursor"
                exit 1
                ;;
        esac
    done
}

# Main ESLint setup function
main() {
    echo -e "${BLUE}ESLint Development Environment Setup${NC}"
    
    # Parse arguments
    parse_arguments "$@"
    
    # Run core amphora setup
    setup_amphora_environment
    
    # ESLint-specific setup
    install_eslint_dependencies
    
    # Install global extensions if requested
    if [ "$GLOBAL_FLAG" = true ]; then
        echo ""
        echo "Installing global editor extensions..."
        install_global_extensions "code" "VSCode"
        install_global_extensions "cursor" "Cursor"
    fi
    
    echo ""
    echo -e "${GREEN}ESLint setup complete!${NC}"
    echo ""
    echo "What was configured:"
    echo "  - ESLint configuration: $ESLINT_CONFIG_PATH"
    echo "  - ESLint dependencies installed"
    if [ "$GLOBAL_FLAG" = true ]; then
        echo "  - Global extensions installed"
    fi
    echo ""
    echo "Repository structure:"
    echo "  - AmphoraExperience/ (root with ESLint configs)"
    echo "  - AmphoraExperience/repos/ (empty container for your repositories)"
    echo ""
    echo "Next steps:"
    echo "  1. Clone your repositories into: $ROOT_STANDARDS_DIR/repos/"
    echo "     Example: cd $ROOT_STANDARDS_DIR/repos && git clone <your-repo-url>"
    echo "  2. Each repository will use the shared ESLint config automatically"
    echo "  3. Individual repositories can have their own .vscode settings if needed"
    
    if [ "$GLOBAL_FLAG" = false ]; then
        echo ""
        echo "To install extensions globally, run:"
        echo "  $0 --global"
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi