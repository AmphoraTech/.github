#!/usr/bin/env bash
set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# ---- Ensure commands are installed ----
require_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: required command '$1' not found. Install it and re-run." >&2
    exit 1
  fi
}
# ---- Ensure jq ----
require_cmd jq

merge_settings() {
  local target="$1"
  local source="$2"

  if [ ! -f "$source" ]; then
    echo "⚠️  Source settings not found: $source — skipping merge."
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  if [ ! -f "$target" ]; then
    echo "{}" > "$target"
  fi

  local tmp
  tmp="$(mktemp)"

  jq --slurpfile src "$source" '. * $src[0]' "$target" > "$tmp"
  mv "$tmp" "$target"
  echo "✅ Merged settings: $source -> $target"
}

merge_extensions() {
  local target="$1"
  local source="$2"

  if [ ! -f "$source" ]; then
    echo "⚠️  Source extensions not found: $source — skipping merge."
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  if [ ! -f "$target" ]; then
    echo "{}" > "$target"
  fi

  local tmp
  tmp="$(mktemp)"

  jq --slurpfile src "$source" '
    . as $t
    | $src[0] as $s
    | ($t * $s)
    | (if ($t.recommendations? or $s.recommendations?) then
         .recommendations = ((($t.recommendations // []) + ($s.recommendations // [])) | unique)
       else . end)
  ' "$target" > "$tmp"

  mv "$tmp" "$target"
  echo "✅ Merged extensions: $source -> $target"
}

setup_global_ide_settings() {
    local ide_name="$1"
    local target_dir="$2"

    # Check if IDE directory exists
    if [ ! -d "$target_dir" ]; then
        echo "$ide_name does not exist in the home directory"
        return
    fi

    echo "Setting up $ide_name global settings..."

    # Copy the corrected local settings to global location
    mkdir -p "$target_dir"

    if [ -f "$SOURCE_SETTINGS" ]; then
        cp "$SOURCE_SETTINGS" "$target_dir/settings.json"
        echo "Copied corrected settings to $ide_name global directory"
    else
        echo "Warning: No source settings found at $SOURCE_SETTINGS"
    fi

    # Copy extensions if they exist
    if [ -f "$SOURCE_EXTENSIONS" ]; then
        cp "$SOURCE_EXTENSIONS" "$target_dir/extensions.json"
        echo "Copied extensions to $ide_name global directory"
    fi
}

# Function to check if an extension is already installed
is_extension_installed() {
    local editor_cmd="$1"
    local extension_id="$2"

    # Get list of installed extensions and check if our extension is in it
    local installed_extensions
    installed_extensions=$($editor_cmd --list-extensions 2>/dev/null || echo "")

    if echo "$installed_extensions" | grep -q "^${extension_id}$"; then
        return 0  # Extension is installed
    else
        return 1  # Extension is not installed
    fi
}

# Function to install extensions from extensions.json
install_extensions() {
    local editor_cmd="$1"
    local editor_name="$2"
    local extensions_file="$3"

    if [ ! -f "$extensions_file" ]; then
        echo "⚠️  Extensions file not found: $extensions_file"
        return 0
    fi

    echo -e "${BLUE}Checking and installing $editor_name extensions from: $extensions_file${NC}"

    # Check if editor CLI command is available
    if ! command -v "$editor_cmd" &>/dev/null; then
        echo -e "${YELLOW}⚠️  $editor_name CLI not available. Extensions need to be installed manually.${NC}"
        if [ "$editor_cmd" = "code" ]; then
            echo -e "${YELLOW}   To enable VSCode CLI: Open VSCode → Command Palette → 'Shell Command: Install code command in PATH'${NC}"
        elif [ "$editor_cmd" = "cursor" ]; then
            echo -e "${YELLOW}   To enable Cursor CLI: Open Cursor → Command Palette → 'Shell Command: Install cursor command in PATH'${NC}"
        fi
        return 0
    fi

    # Extract extension IDs and install them
    local extensions
    extensions=$(jq -r '.recommendations[]' "$extensions_file" 2>/dev/null || echo "")

    if [ -z "$extensions" ]; then
        echo "⚠️  No extensions found in $extensions_file"
        return 0
    fi

    echo "Checking extensions for $editor_name:"
    local installed_count=0
    local skipped_count=0
    local failed_count=0

    while IFS= read -r extension; do
        if [ -n "$extension" ]; then
            if is_extension_installed "$editor_cmd" "$extension"; then
                echo "  ⏭️  Already installed: $extension"
                ((skipped_count++))
            else
                echo "  📦 Installing: $extension"
                if $editor_cmd --install-extension "$extension" --force >/dev/null 2>&1; then
                    echo "    ✅ Successfully installed: $extension"
                    ((installed_count++))
                else
                    echo "    ❌ Failed to install: $extension"
                    ((failed_count++))
                fi
            fi
        fi
    done <<< "$extensions"

    echo ""
    echo -e "${GREEN}✅ $editor_name extension check complete!${NC}"
    echo -e "${GREEN}   Newly installed: $installed_count extensions${NC}"
    echo -e "${BLUE}   Already installed: $skipped_count extensions${NC}"
    if [ $failed_count -gt 0 ]; then
        echo -e "${RED}   Failed: $failed_count extensions${NC}"
    fi
    echo ""
}

# Function to fix the local settings file first
fix_local_eslint_config() {
    local settings_file="$1"
    local eslint_config_path="$2"

    if [ ! -f "$settings_file" ]; then
        echo "Creating new settings file: $settings_file"
        echo "{}" > "$settings_file"
    fi

    echo -e "${BLUE}Fixing ESLint config path in local settings: $settings_file${NC}"

    local tmp
    tmp="$(mktemp)"

    # Only update the overrideConfigFile property, preserve everything else
    jq --arg config_path "$eslint_config_path" '
        .["eslint.options"] = (.["eslint.options"] // {}) | .["eslint.options"]["overrideConfigFile"] = $config_path
    ' "$settings_file" > "$tmp"

    mv "$tmp" "$settings_file"
    echo "Added correct ESLint path to $settings_file"
}

fix_local_python_flake8_config() {
    local settings_file="$1"
    local python_flake8_config_path="$2"

    if [ ! -f "$settings_file" ]; then
        echo "Creating new settings file: $settings_file"
        echo "{}" > "$settings_file"
    fi

    local tmp
    tmp="$(mktemp)"

    # Only update the overrideConfigFile property, preserve everything else
    jq --arg config_path "$python_flake8_config_path" '
        .["python.linting.flake8Args"] = (.["python.linting.flake8Args"] // []) | .["python.linting.flake8Args"] = $config_path
    ' "$settings_file" > "$tmp"

    mv "$tmp" "$settings_file"
    echo "Added Python flake8 path to $settings_file"
}

fix_local_python_toml_config() {
    local settings_file="$1"
    local python_toml_config_path="$2"

    if [ ! -f "$settings_file" ]; then
        echo "Creating new settings file: $settings_file"
        echo "{}" > "$settings_file"
    fi

    local tmp
    tmp="$(mktemp)"

    # Only update the overrideConfigFile property, preserve everything else
    jq --arg config_path "$python_toml_config_path" '
        .["python.formatting.blackArgs"] = (.["python.formatting.blackArgs"] // []) | .["python.formatting.blackArgs"] = $config_path | .["python.sortImports.args"] = (.["python.sortImports.args"] // []) | .["python.sortImports.args"] = $config_path
    ' "$settings_file" > "$tmp"

    mv "$tmp" "$settings_file"
    echo "Added correct Python toml path to $settings_file"
}

# Function to create or ensure extensions.json exists
ensure_extensions_json() {
    if [ ! -f "$SOURCE_EXTENSIONS" ]; then
        echo -e "${BLUE}Creating extensions.json with your current extensions...${NC}"
        mkdir -p "$(dirname "$SOURCE_EXTENSIONS")"

        cat > "$SOURCE_EXTENSIONS" << 'EOF'
{
  "recommendations": [
    "esbenp.prettier-vscode",
    "dbaeumer.vscode-eslint",
    "ms-vscode.vscode-typescript-next",
    "msjsdiag.vscode-react-native",
    "Vue.volar",
    "bradlc.vscode-tailwindcss",
    "christian-kohler.path-intellisense",
    "rokoroku.vscode-theme-darcula"
  ]
}
EOF
        echo "✅ Created extensions.json with your current extensions"
    else
        echo "✅ Extensions.json already exists"
    fi
}

# ---- Detect OS paths ----
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    HOME_DIR="$HOME"
    VSCODE_USER_DIR="$HOME_DIR/Library/Application Support/Code/User"
    CURSOR_USER_DIR="$HOME_DIR/Library/Application Support/Cursor/User"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    HOME_DIR="$HOME"
    VSCODE_USER_DIR="$HOME_DIR/.config/Code/User"
    CURSOR_USER_DIR="$HOME_DIR/.config/Cursor/User"
  elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    HOME_DIR="$USERPROFILE"
    VSCODE_USER_DIR="$HOME_DIR/AppData/Roaming/Code/User"
    CURSOR_USER_DIR="$HOME_DIR/AppData/Roaming/Cursor/User"
  else
    echo "Unsupported OSTYPE: $OSTYPE" >&2
    exit 1
  fi
}

get_standards_dir() {
  ROOT_STANDARDS_DIR="$HOME_DIR/amphora-logistics-code-standards"
  ESLINT_STANDARDS_DIR="$ROOT_STANDARDS_DIR/configs/eslint"
  PYTHON_STANDARDS_DIR="$ROOT_STANDARDS_DIR/configs/python"
}

get_source_settings() {
  SOURCE_SETTINGS="$ROOT_STANDARDS_DIR/.vscode/settings.json"
}

get_source_extensions() {
  SOURCE_EXTENSIONS="$ROOT_STANDARDS_DIR/.vscode/extensions.json"
}

get_eslint_config_path() {
  ESLINT_CONFIG_PATH="$ESLINT_STANDARDS_DIR/eslint.config.js"
}

get_python_toml_config_path() {
  PYTHON_TOML_CONFIG_PATH="$PYTHON_STANDARDS_DIR/pyproject.toml"
}

get_python_flake8_config_path() {
  PYTHON_FLAKE8_CONFIG_PATH="$PYTHON_STANDARDS_DIR/.flake8"
}

get_current_dir() {
  CURRENT_DIR="$(pwd)"
}

move_standards_dir() {
  # Check if we're already in the home directory location
  if [ "$CURRENT_DIR" != "$ROOT_STANDARDS_DIR" ]; then
      echo "Moving logistics-code-standards to user home directory..."

      # If target exists, remove it first
      if [ -d "$ROOT_STANDARDS_DIR" ]; then
          rm -rf "$ROOT_STANDARDS_DIR"
      fi

      # Move (not copy) current directory to home
      mv "$CURRENT_DIR" "$ROOT_STANDARDS_DIR"
      cd "$ROOT_STANDARDS_DIR"

      echo "Moved to: $ROOT_STANDARDS_DIR"
  else
      echo "Already in correct location: $ROOT_STANDARDS_DIR"
  fi
}

install_eslint_dependencies() {
  # go to to eslint config and install dependencies
  cd "$ESLINT_STANDARDS_DIR"
  echo "Installing ESLint dependencies in $(dirname "$ESLINT_STANDARDS_DIR")" # eslint directory
  npm install
  cd "$ROOT_STANDARDS_DIR" #back to the standards directory
}

install_python_dependencies() {
  # go to to python config and install dependencies
  cd "$PYTHON_STANDARDS_DIR"
  echo "Installing Python dependencies in $(dirname "$PYTHON_STANDARDS_DIR")" # python directory
  pip install -r requirements-linting.txt
  cd "$ROOT_STANDARDS_DIR" #back to the standards directory
}

main() {
    echo -e "${BLUE}🚀 Setting up Global Linters and Formatters Configuration${NC}"
    echo ""

    detect_os
    get_standards_dir
    get_source_settings
    get_source_extensions
    get_eslint_config_path
    get_python_toml_config_path
    get_python_flake8_config_path
    get_current_dir
    move_standards_dir
    ensure_extensions_json  # Make sure extensions.json exists
    install_eslint_dependencies
    # install_python_dependencies # WHEN PYTHON IS READY - ETTORE

    echo ""
    echo -e "Root standards directory: ${BLUE}$ROOT_STANDARDS_DIR${NC}"
    echo -e "Source settings: ${BLUE}$SOURCE_SETTINGS${NC}"
    echo -e "Source extensions: ${BLUE}$SOURCE_EXTENSIONS${NC}"
    echo -e "ESLint config path: ${BLUE}$ESLINT_CONFIG_PATH${NC}"
    echo -e "Python toml config path: ${BLUE}$PYTHON_TOML_CONFIG_PATH${NC}"
    echo -e "Python flake8 config path: ${BLUE}$PYTHON_FLAKE8_CONFIG_PATH${NC}"
    echo -e "VSCode user directory: ${BLUE}$VSCODE_USER_DIR${NC}"
    echo -e "Cursor user directory: ${BLUE}$CURSOR_USER_DIR${NC}"
    echo ""

    # Setup VSCode
    if [ -d "$VSCODE_USER_DIR" ]; then
      echo -e "${GREEN}VSCode exists in the home directory${NC}"
      fix_local_eslint_config "$SOURCE_SETTINGS" "$ESLINT_CONFIG_PATH"
      fix_local_python_flake8_config "$SOURCE_SETTINGS" "$PYTHON_FLAKE8_CONFIG_PATH"
      fix_local_python_toml_config "$SOURCE_SETTINGS" "$PYTHON_TOML_CONFIG_PATH"
      setup_global_ide_settings "VSCode" "$VSCODE_USER_DIR"  # Fixed function name
      merge_settings "$VSCODE_USER_DIR/settings.json" "$SOURCE_SETTINGS"
      merge_extensions "$VSCODE_USER_DIR/extensions.json" "$SOURCE_EXTENSIONS"

      # Install extensions automatically
      install_extensions "code" "VSCode" "$SOURCE_EXTENSIONS"
    else
      echo -e "${YELLOW}VSCode does not exist in the home directory${NC}"
    fi

    # Setup Cursor
    if [ -d "$CURSOR_USER_DIR" ]; then
      echo -e "${GREEN}Cursor exists in the home directory${NC}"
      fix_local_eslint_config "$SOURCE_SETTINGS" "$ESLINT_CONFIG_PATH"
      fix_local_python_flake8_config "$SOURCE_SETTINGS" "$PYTHON_FLAKE8_CONFIG_PATH"
      fix_local_python_toml_config "$SOURCE_SETTINGS" "$PYTHON_TOML_CONFIG_PATH"
      setup_global_ide_settings "Cursor" "$CURSOR_USER_DIR"
      merge_settings "$CURSOR_USER_DIR/settings.json" "$SOURCE_SETTINGS"
      merge_extensions "$CURSOR_USER_DIR/extensions.json" "$SOURCE_EXTENSIONS"

      # Install extensions automatically
      install_extensions "cursor" "Cursor" "$SOURCE_EXTENSIONS"
    else
      echo -e "${YELLOW}Cursor does not exist in the home directory${NC}"
    fi

    echo ""
    echo -e "${GREEN}✅ Global ESLint setup complete!${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Restart VSCode/Cursor to load new settings and extensions"
    echo "2. Extensions should now be installed automatically"
    echo "3. Test with: npm run lint"
    echo ""
    echo -e "${BLUE}Global ESLINT configuration location:${NC} $ROOT_STANDARDS_DIR/configs/eslint/eslint.config.js"
    echo -e "${BLUE}Global PYTHON configuration:${NC} $ROOT_STANDARDS_DIR/configs/python/pyproject.toml"
    echo -e "${BLUE}Global PYTHON flake8 configuration:${NC} $ROOT_STANDARDS_DIR/configs/python/.flake8"
}

# Initialize script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
