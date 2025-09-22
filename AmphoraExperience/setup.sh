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

# Function to MERGE settings without overwriting existing ones
fix_local_eslint_config() {
    local settings_file="$1"
    local eslint_config_path="$2"

    if [ ! -f "$settings_file" ]; then
        echo "Creating new settings file: $settings_file"
        mkdir -p "$(dirname "$settings_file")"
        echo "{}" > "$settings_file"
    fi

    echo -e "${BLUE}Merging ESLint config path into existing settings: $settings_file${NC}"

    local tmp
    tmp="$(mktemp)"

    # PROPERLY merge - preserve ALL existing properties and only add/update eslint.options
    jq --arg config_path "$eslint_config_path" '
        # Preserve the entire object and only modify eslint.options
        . as $original |
        $original |
        .["eslint.options"] = ((.["eslint.options"] // {}) + {"overrideConfigFile": $config_path})
    ' "$settings_file" > "$tmp"

    if [ $? -eq 0 ]; then
        mv "$tmp" "$settings_file"
        echo "✅ Successfully merged ESLint config into $settings_file"
    else
        rm "$tmp"
        echo "❌ Failed to merge ESLint config"
    fi
}

fix_local_python_flake8_config() {
    local settings_file="$1"
    local python_flake8_config_path="$2"

    if [ ! -f "$settings_file" ]; then
        echo "Creating new settings file: $settings_file"
        mkdir -p "$(dirname "$settings_file")"
        echo "{}" > "$settings_file"
    fi

    echo -e "${BLUE}Merging Python flake8 config into existing settings: $settings_file${NC}"

    local tmp
    tmp="$(mktemp)"

    # PROPERLY merge - preserve ALL existing properties and only add/update python.linting.flake8Args
    jq --arg config_path "$python_flake8_config_path" '
        # Preserve the entire object and only modify python.linting.flake8Args
        . as $original |
        $original |
        .["python.linting.flake8Args"] = ["--config", $config_path]
    ' "$settings_file" > "$tmp"

    if [ $? -eq 0 ]; then
        mv "$tmp" "$settings_file"
        echo "✅ Successfully merged Python flake8 config into $settings_file"
    else
        rm "$tmp"
        echo "❌ Failed to merge Python flake8 config"
    fi
}

fix_local_python_toml_config() {
    local settings_file="$1"
    local python_toml_config_path="$2"

    if [ ! -f "$settings_file" ]; then
        echo "Creating new settings file: $settings_file"
        mkdir -p "$(dirname "$settings_file")"
        echo "{}" > "$settings_file"
    fi

    echo -e "${BLUE}Merging Python toml config into existing settings: $settings_file${NC}"

    local tmp
    tmp="$(mktemp)"

    # PROPERLY merge - preserve ALL existing properties and only add/update python formatting settings
    jq --arg config_path "$python_toml_config_path" '
        # Preserve the entire object and only modify the specific python settings
        . as $original |
        $original |
        .["python.formatting.blackArgs"] = ["--config", $config_path] |
        .["python.sortImports.args"] = ["--settings-path", $config_path]
    ' "$settings_file" > "$tmp"

    if [ $? -eq 0 ]; then
        mv "$tmp" "$settings_file"
        echo "✅ Successfully merged Python toml config into $settings_file"
    else
        rm "$tmp"
        echo "❌ Failed to merge Python toml config"
    fi
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
      DESKTOP_PATH="$HOME_DIR/Desktop"
      VSCODE_USER_DIR="$HOME_DIR/Library/Application Support/Code/User"
      CURSOR_USER_DIR="$HOME_DIR/Library/Application Support/Cursor/User"
   elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      HOME_DIR="$HOME"
      DESKTOP_PATH="$HOME_DIR/Desktop"
      VSCODE_USER_DIR="$HOME_DIR/.config/Code/User"
      CURSOR_USER_DIR="$HOME_DIR/.config/Cursor/User"
   elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
      HOME_DIR="$USERPROFILE"
      DESKTOP_PATH="$HOME_DIR/Desktop"
      VSCODE_USER_DIR="$HOME_DIR/AppData/Roaming/Code/User"
      CURSOR_USER_DIR="$HOME_DIR/AppData/Roaming/Cursor/User"
   else
      echo "Unsupported OSTYPE: $OSTYPE" >&2
      exit 1
   fi
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
                echo "Unknown option: $1"
                echo "Usage: $0 [--global]"
                echo "  --global  Copy/merge settings to VSCode/Cursor global directories"
                exit 1
                ;;
        esac
    done
}

get_current_dir() {
  CURRENT_DIR="$(pwd)"
  FOLDER_NAME="$(basename "$CURRENT_DIR")"
  echo "Current directory: $CURRENT_DIR"
  echo "Current folder name: $FOLDER_NAME"
}

# FIXED: Detect script location and find target folder (looking for repos and configs OR code-standards)
detect_target_folder() {
  # Case 1: Script is inside the target folder (e.g., AmphoraExperience/setup.sh)
  if [ -d "$CURRENT_DIR/repos" ] && ([ -d "$CURRENT_DIR/configs" ] || [ -d "$CURRENT_DIR/code-standards" ]); then
    echo "✅ Script is inside target folder: $FOLDER_NAME"
    TARGET_FOLDER_PATH="$CURRENT_DIR"
    TARGET_FOLDER_NAME="$FOLDER_NAME"
    return 0
  fi

  # Case 2: Script at root level, need to find the target folder
  echo "🔍 Script at root level, searching for target folder..."

  # Look for folders that contain 'repos' and either 'configs' or 'code-standards' subdirectories
  for dir in "$CURRENT_DIR"/*/ ; do
    if [ -d "$dir" ]; then
      dir_name=$(basename "$dir")
      if [ -d "$dir/repos" ] && ([ -d "$dir/configs" ] || [ -d "$dir/code-standards" ]); then
        echo "✅ Found target folder: $dir_name"
        TARGET_FOLDER_PATH="$dir"
        TARGET_FOLDER_NAME="$dir_name"
        return 0
      fi
    fi
  done

  # If we get here, no target folder was found
  echo "❌ No target folder found with both 'repos' and ('configs' or 'code-standards') directories"
  echo "Expected structure:"
  echo "  - repos/"
  echo "  - configs/ OR code-standards/"
  exit 1
}

# Copy the target folder to desktop
copy_standards_dir_to_desktop() {
   # Set the target path on desktop
   ROOT_STANDARDS_DIR="$DESKTOP_PATH/$TARGET_FOLDER_NAME"

   echo "Target folder path: $TARGET_FOLDER_PATH"
   echo "Target folder name: $TARGET_FOLDER_NAME"
   echo "Target desktop path: $ROOT_STANDARDS_DIR"

   # Check if target folder is already on desktop
   if [ "$TARGET_FOLDER_PATH" = "$ROOT_STANDARDS_DIR" ]; then
      echo "Already in correct location: $ROOT_STANDARDS_DIR"
      return 0
   fi

   echo "Copying $TARGET_FOLDER_NAME to desktop..."

   # If target exists on desktop, remove it first
   if [ -d "$ROOT_STANDARDS_DIR" ]; then
       echo "Removing existing $TARGET_FOLDER_NAME from desktop..."
       rm -rf "$ROOT_STANDARDS_DIR"
   fi

   # Copy the target folder to desktop
   echo "Copying from: $TARGET_FOLDER_PATH"
   echo "Copying to: $ROOT_STANDARDS_DIR"

   cp -r "$TARGET_FOLDER_PATH" "$ROOT_STANDARDS_DIR"
   cd "$ROOT_STANDARDS_DIR"

   echo "✅ Copied to desktop: $ROOT_STANDARDS_DIR"

   # Update paths to reflect new location
   CURRENT_DIR="$ROOT_STANDARDS_DIR"
   TARGET_FOLDER_PATH="$ROOT_STANDARDS_DIR"
}

# FIXED: Set up directory paths with correct nested structure
setup_directory_paths() {
   echo "🔍 Detecting directory structure..."
   echo "Available directories:"
   ls -la "$ROOT_STANDARDS_DIR" | grep "^d"

   # PRIORITY 1: Check if code-standards/configs/eslint exists (actual structure)
   if [ -d "$ROOT_STANDARDS_DIR/code-standards/configs" ] && [ -d "$ROOT_STANDARDS_DIR/code-standards/configs/eslint" ]; then
     echo "✅ Using nested 'code-standards/configs' directory structure"
     ESLINT_STANDARDS_DIR="$ROOT_STANDARDS_DIR/code-standards/configs/eslint"
     PYTHON_STANDARDS_DIR="$ROOT_STANDARDS_DIR/code-standards/configs/python"
   # PRIORITY 2: Check if configs/eslint exists (flat structure)
   elif [ -d "$ROOT_STANDARDS_DIR/configs" ] && [ -d "$ROOT_STANDARDS_DIR/configs/eslint" ]; then
     echo "✅ Using flat 'configs' directory structure"
     ESLINT_STANDARDS_DIR="$ROOT_STANDARDS_DIR/configs/eslint"
     PYTHON_STANDARDS_DIR="$ROOT_STANDARDS_DIR/configs/python"
   # PRIORITY 3: Check if code-standards/eslint exists (direct structure)
   elif [ -d "$ROOT_STANDARDS_DIR/code-standards" ] && [ -d "$ROOT_STANDARDS_DIR/code-standards/eslint" ]; then
     echo "✅ Using direct 'code-standards/eslint' directory structure"
     ESLINT_STANDARDS_DIR="$ROOT_STANDARDS_DIR/code-standards/eslint"
     PYTHON_STANDARDS_DIR="$ROOT_STANDARDS_DIR/code-standards/python"
   # FALLBACK 1: Just code-standards/configs directory exists
   elif [ -d "$ROOT_STANDARDS_DIR/code-standards/configs" ]; then
     echo "⚠️ Using 'code-standards/configs' directory structure (fallback)"
     ESLINT_STANDARDS_DIR="$ROOT_STANDARDS_DIR/code-standards/configs/eslint"
     PYTHON_STANDARDS_DIR="$ROOT_STANDARDS_DIR/code-standards/configs/python"
   # FALLBACK 2: Just configs directory exists
   elif [ -d "$ROOT_STANDARDS_DIR/configs" ]; then
     echo "⚠️ Using 'configs' directory structure (fallback)"
     ESLINT_STANDARDS_DIR="$ROOT_STANDARDS_DIR/configs/eslint"
     PYTHON_STANDARDS_DIR="$ROOT_STANDARDS_DIR/configs/python"
   # FALLBACK 3: Just code-standards directory exists
   elif [ -d "$ROOT_STANDARDS_DIR/code-standards" ]; then
     echo "⚠️ Using 'code-standards' directory structure (fallback)"
     ESLINT_STANDARDS_DIR="$ROOT_STANDARDS_DIR/code-standards/eslint"
     PYTHON_STANDARDS_DIR="$ROOT_STANDARDS_DIR/code-standards/python"
   else
     echo "❌ No valid directory structure found"
     exit 1
   fi

   SOURCE_SETTINGS="$ROOT_STANDARDS_DIR/repos/.vscode/settings.json"
   SOURCE_EXTENSIONS="$ROOT_STANDARDS_DIR/repos/.vscode/extensions.json"
   ESLINT_CONFIG_PATH="$ESLINT_STANDARDS_DIR/eslint.config.js"
   PYTHON_TOML_CONFIG_PATH="$PYTHON_STANDARDS_DIR/pyproject.toml"
   PYTHON_FLAKE8_CONFIG_PATH="$PYTHON_STANDARDS_DIR/.flake8"

   echo "📂 Final paths:"
   echo "   ESLint directory: $ESLINT_STANDARDS_DIR"
   echo "   Python directory: $PYTHON_STANDARDS_DIR"
}

install_eslint_dependencies() {
  # Make sure we're in the right directory first
  if [ -d "$ESLINT_STANDARDS_DIR" ]; then
    echo "Installing ESLint dependencies in $ESLINT_STANDARDS_DIR"
    cd "$ESLINT_STANDARDS_DIR"

    # Check if package.json exists
    if [ -f "package.json" ]; then
      echo "Found package.json, running npm install..."
      npm install
      echo "✅ ESLint dependencies installed successfully"
    else
      echo "⚠️ No package.json found in $ESLINT_STANDARDS_DIR"
      echo "Available files:"
      ls -la
    fi

    # Return to root standards directory
    cd "$ROOT_STANDARDS_DIR"
  else
    echo "❌ ESLint directory not found: $ESLINT_STANDARDS_DIR"
    echo "Let's debug what's available:"
    echo "Contents of $ROOT_STANDARDS_DIR:"
    find "$ROOT_STANDARDS_DIR" -type d -name "*eslint*" -o -name "*config*" | head -20
  fi
}

main() {
    echo -e "${BLUE}🚀 Setting up Global Linters and Formatters Configuration${NC}"
    echo ""

    # Parse command line arguments first
    parse_arguments "$@"

    detect_os
    get_current_dir

    # Detect where the script is running and find the target folder
    detect_target_folder

    # Copy target folder to desktop
    copy_standards_dir_to_desktop

    # Set up all paths after copy (using ROOT_STANDARDS_DIR)
    setup_directory_paths

    # Create necessary directories and files
    ensure_extensions_json  # Make sure extensions.json exists

    # Install dependencies
    install_eslint_dependencies
    # install_python_dependencies # WHEN PYTHON IS READY - ETTORE

    echo ""
    echo -e "Root standards directory: ${BLUE}$ROOT_STANDARDS_DIR${NC}"
    echo -e "Source settings: ${BLUE}$SOURCE_SETTINGS${NC}"
    echo -e "Source extensions: ${BLUE}$SOURCE_EXTENSIONS${NC}"
    echo -e "ESLint config path: ${BLUE}$ESLINT_CONFIG_PATH${NC}"
    echo -e "Python toml config path: ${BLUE}$PYTHON_TOML_CONFIG_PATH${NC}"
    echo -e "Python flake8 config path: ${BLUE}$PYTHON_FLAKE8_CONFIG_PATH${NC}"

    if [ "$GLOBAL_FLAG" = true ]; then
        echo -e "VSCode user directory: ${BLUE}$VSCODE_USER_DIR${NC}"
        echo -e "Cursor user directory: ${BLUE}$CURSOR_USER_DIR${NC}"
    fi
    echo ""

    # ALWAYS configure local settings in repos/.vscode/settings.json
    echo -e "${BLUE}Configuring local settings in $SOURCE_SETTINGS${NC}"
    fix_local_eslint_config "$SOURCE_SETTINGS" "$ESLINT_CONFIG_PATH"
    fix_local_python_flake8_config "$SOURCE_SETTINGS" "$PYTHON_FLAKE8_CONFIG_PATH"
    fix_local_python_toml_config "$SOURCE_SETTINGS" "$PYTHON_TOML_CONFIG_PATH"
    echo -e "${GREEN}✅ Local settings configured${NC}"

    # ONLY setup global IDE settings if --global flag is present
    if [ "$GLOBAL_FLAG" = true ]; then
        echo ""
        echo -e "${YELLOW}Global flag detected - setting up VSCode/Cursor global settings${NC}"

        # Setup VSCode
        if [ -d "$VSCODE_USER_DIR" ]; then
          echo -e "${GREEN}VSCode exists in the home directory${NC}"
          setup_global_ide_settings "VSCode" "$VSCODE_USER_DIR"
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
          setup_global_ide_settings "Cursor" "$CURSOR_USER_DIR"
          merge_settings "$CURSOR_USER_DIR/settings.json" "$SOURCE_SETTINGS"
          merge_extensions "$CURSOR_USER_DIR/extensions.json" "$SOURCE_EXTENSIONS"

          # Install extensions automatically
          install_extensions "cursor" "Cursor" "$SOURCE_EXTENSIONS"
        else
          echo -e "${YELLOW}Cursor does not exist in the home directory${NC}"
        fi
    else
        echo -e "${BLUE}Local setup only (use --global flag to setup VSCode/Cursor global settings)${NC}"
    fi

    echo ""
    echo -e "${GREEN}✅ Setup complete!${NC}"
    echo ""
    echo -e "${YELLOW}What was done:${NC}"
    echo "1. Copied $TARGET_FOLDER_NAME to desktop: $ROOT_STANDARDS_DIR"
    echo "2. Configured local settings in: $SOURCE_SETTINGS"
    if [ "$GLOBAL_FLAG" = true ]; then
        echo "3. Updated global VSCode/Cursor settings and extensions"
    fi
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    if [ "$GLOBAL_FLAG" = true ]; then
        echo "1. Restart VSCode/Cursor to load new global settings and extensions"
        echo "2. Extensions should now be installed automatically"
    else
        echo "1. Open VSCode/Cursor in the desktop project directory"
        echo "2. Local settings will be applied automatically"
    fi
    echo "3. Test with: npm run lint"
    echo ""
    echo -e "${BLUE}Local settings configured in:${NC} $SOURCE_SETTINGS"
    if [[ "$ESLINT_STANDARDS_DIR" == *"/configs/"* ]]; then
        echo -e "${BLUE}Global ESLINT configuration:${NC} $ESLINT_STANDARDS_DIR/eslint.config.js"
        echo -e "${BLUE}Global PYTHON configuration:${NC} $PYTHON_STANDARDS_DIR/pyproject.toml"
        echo -e "${BLUE}Global PYTHON flake8 configuration:${NC} $PYTHON_STANDARDS_DIR/.flake8"
    else
        echo -e "${BLUE}Global ESLINT configuration:${NC} $ESLINT_STANDARDS_DIR/eslint.config.js"
        echo -e "${BLUE}Global PYTHON configuration:${NC} $PYTHON_STANDARDS_DIR/pyproject.toml"
        echo -e "${BLUE}Global PYTHON flake8 configuration:${NC} $PYTHON_STANDARDS_DIR/.flake8"
    fi
}

# Initialize script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
