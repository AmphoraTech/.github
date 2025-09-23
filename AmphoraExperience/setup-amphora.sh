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

get_current_dir() {
  CURRENT_DIR="$(pwd)"
  FOLDER_NAME="$(basename "$CURRENT_DIR")"
  echo "Current directory: $CURRENT_DIR"
  echo "Current folder name: $FOLDER_NAME"
}

# Detect script location and find target folder
detect_target_folder() {
  # Case 1: Script is inside the target folder
  if [ -d "$CURRENT_DIR/repos" ] && ([ -d "$CURRENT_DIR/configs" ] || [ -d "$CURRENT_DIR/code-standards" ]); then
    echo "Script is inside target folder: $FOLDER_NAME"
    TARGET_FOLDER_PATH="$CURRENT_DIR"
    TARGET_FOLDER_NAME="$FOLDER_NAME"
    return 0
  fi

  # Case 2: Script at root level, search for target folder
  echo "Script at root level, searching for target folder..."
  for dir in "$CURRENT_DIR"/*/ ; do
    if [ -d "$dir" ]; then
      dir_name=$(basename "$dir")
      if [ -d "$dir/repos" ] && ([ -d "$dir/configs" ] || [ -d "$dir/code-standards" ]); then
        echo "Found target folder: $dir_name"
        TARGET_FOLDER_PATH="$dir"
        TARGET_FOLDER_NAME="$dir_name"
        return 0
      fi
    fi
  done

  echo "No target folder found with both 'repos' and ('configs' or 'code-standards') directories"
  exit 1
}

# Copy the target folder to desktop while preserving existing directories
copy_standards_dir_to_desktop() {
   ROOT_STANDARDS_DIR="$DESKTOP_PATH/$TARGET_FOLDER_NAME"

   echo "Target folder path: $TARGET_FOLDER_PATH"
   echo "Target folder name: $TARGET_FOLDER_NAME"
   echo "Target desktop path: $ROOT_STANDARDS_DIR"

   if [ "$TARGET_FOLDER_PATH" = "$ROOT_STANDARDS_DIR" ]; then
      echo "Already in correct location: $ROOT_STANDARDS_DIR"
      return 0
   fi

   echo "Copying $TARGET_FOLDER_NAME to desktop..."

   # Detect existing directories to preserve
   EXISTING_DIRS=()
   if [ -d "$ROOT_STANDARDS_DIR" ]; then
       echo "Destination exists, checking directories to preserve..."
       PRESERVE_DIRS=("repos" "certificates" "local-configs" "user-data")
       
       for dir in "${PRESERVE_DIRS[@]}"; do
           if [ -d "$ROOT_STANDARDS_DIR/$dir" ]; then
               EXISTING_DIRS+=("$dir")
               echo "   - Will preserve: $dir/"
           fi
       done
   fi

   # Detect git information
   ORIGINAL_GIT_DIR=""
   GIT_REMOTE_URL=""
   GIT_BRANCH=""
   
   current_path="$TARGET_FOLDER_PATH"
   while [ "$current_path" != "/" ]; do
       if [ -d "$current_path/.git" ]; then
           ORIGINAL_GIT_DIR="$current_path"
           break
       fi
       current_path=$(dirname "$current_path")
   done

   if [ -n "$ORIGINAL_GIT_DIR" ]; then
       echo "Detected git repository at: $ORIGINAL_GIT_DIR"
       cd "$ORIGINAL_GIT_DIR"
       GIT_REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
       GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
       echo "Git remote: $GIT_REMOTE_URL"
       echo "Git branch: $GIT_BRANCH"
   fi

   # Build exclude patterns
   EXCLUDE_PATTERNS=()
   if [ ${#EXISTING_DIRS[@]} -gt 0 ]; then
       for dir in "${EXISTING_DIRS[@]}"; do
           EXCLUDE_PATTERNS+=("--exclude=$dir")
       done
   fi

   # Perform copy with rsync or cp fallback
   if command -v rsync >/dev/null 2>&1; then
       echo "Using rsync for selective copying..."
       
       rsync_cmd=(rsync -av)
       
       # Add existing directory excludes
       if [ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]; then
           for pattern in "${EXCLUDE_PATTERNS[@]}"; do
               rsync_cmd+=("$pattern")
           done
       fi
       
       # Check if repos should be filtered
       repos_exists=false
       if [ ${#EXISTING_DIRS[@]} -gt 0 ]; then
           for dir in "${EXISTING_DIRS[@]}"; do
               if [ "$dir" = "repos" ]; then
                   repos_exists=true
                   break
               fi
           done
       fi
       
       if [ "$repos_exists" = false ]; then
           rsync_cmd+=(--include='repos/' --include='repos/*.md' --exclude='repos/*')
       fi
       
       # Exclude development artifacts
       rsync_cmd+=(
           --exclude='.history/'
           --exclude='node_modules/'
           --exclude='package-lock.json'
           --exclude='yarn.lock'
           --exclude='npm-debug.log'
           --exclude='yarn-error.log'
           --exclude='dist/'
           --exclude='build/'
           --exclude='.next/'
           --exclude='coverage/'
           --exclude='android/'
           --exclude='ios/'
           --exclude='.expo/'
           --exclude='.DS_Store'
           --exclude='*.sh'
       )
       
       rsync_cmd+=("$TARGET_FOLDER_PATH/" "$ROOT_STANDARDS_DIR/")
       "${rsync_cmd[@]}"
       
   else
       echo "Using cp fallback method..."
       mkdir -p "$ROOT_STANDARDS_DIR"
       temp_copy_dir=$(mktemp -d)
       cp -r "$TARGET_FOLDER_PATH"/* "$temp_copy_dir/" 2>/dev/null || true
       
       # Remove preserved directories and artifacts
       if [ ${#EXISTING_DIRS[@]} -gt 0 ]; then
           for dir in "${EXISTING_DIRS[@]}"; do
               [ -d "$temp_copy_dir/$dir" ] && rm -rf "$temp_copy_dir/$dir"
           done
       fi
       
       # Clean artifacts
       artifacts=('.history' 'node_modules' 'package-lock.json' 'yarn.lock' 'npm-debug.log' 'yarn-error.log' 'dist' 'build' '.next' 'coverage' 'android' 'ios' '.expo' '.DS_Store')
       for artifact in "${artifacts[@]}"; do
           find "$temp_copy_dir" -name "$artifact" -exec rm -rf {} + 2>/dev/null || true
       done
       find "$temp_copy_dir" -name "*.sh" -exec rm -f {} + 2>/dev/null || true
       
       # Handle repos cleanup if needed
       if [ "$repos_exists" = false ] && [ -d "$temp_copy_dir/repos" ]; then
           temp_md_dir=$(mktemp -d)
           find "$temp_copy_dir/repos" -name "*.md" -exec cp {} "$temp_md_dir/" \; 2>/dev/null || true
           rm -rf "$temp_copy_dir/repos"/*
           [ "$(ls -A "$temp_md_dir" 2>/dev/null)" ] && cp "$temp_md_dir"/*.md "$temp_copy_dir/repos/" 2>/dev/null || true
           rm -rf "$temp_md_dir"
       fi
       
       cp -r "$temp_copy_dir"/* "$ROOT_STANDARDS_DIR/" 2>/dev/null || true
       rm -rf "$temp_copy_dir"
   fi

   cd "$ROOT_STANDARDS_DIR"

   # Setup git connection
   if [ -n "$ORIGINAL_GIT_DIR" ] && [ -n "$GIT_REMOTE_URL" ]; then
       echo "Setting up git repository..."
       [ ! -d ".git" ] && git init
       
       if ! git remote get-url origin >/dev/null 2>&1; then
           git remote add origin "$GIT_REMOTE_URL"
       fi
       
       git fetch origin
       git checkout -b "$GIT_BRANCH" "origin/$GIT_BRANCH" 2>/dev/null || git checkout "$GIT_BRANCH" 2>/dev/null || true
       git branch --set-upstream-to=origin/$GIT_BRANCH $GIT_BRANCH 2>/dev/null || true
       
       echo "Git setup complete: $GIT_REMOTE_URL ($GIT_BRANCH)"
   fi

   echo ""
   echo "Copy completed:"
   echo "   - Updated: Configuration files and standards"
   if [ ${#EXISTING_DIRS[@]} -gt 0 ]; then
       echo "   - Preserved: ${EXISTING_DIRS[*]}"
   fi

   CURRENT_DIR="$ROOT_STANDARDS_DIR"
   TARGET_FOLDER_PATH="$ROOT_STANDARDS_DIR"
}

# Set up directory paths dynamically (compatible with older bash)
setup_directory_paths() {
   echo "Detecting directory structure..."
   
   # Find the base configs directory
   CONFIGS_BASE_DIR=""
   if [ -d "$ROOT_STANDARDS_DIR/code-standards/configs" ]; then
     CONFIGS_BASE_DIR="$ROOT_STANDARDS_DIR/code-standards/configs"
     echo "Using nested structure: code-standards/configs/"
   elif [ -d "$ROOT_STANDARDS_DIR/configs" ]; then
     CONFIGS_BASE_DIR="$ROOT_STANDARDS_DIR/configs"
     echo "Using flat structure: configs/"
   elif [ -d "$ROOT_STANDARDS_DIR/code-standards" ]; then
     CONFIGS_BASE_DIR="$ROOT_STANDARDS_DIR/code-standards"
     echo "Using direct structure: code-standards/"
   else
     echo "No valid configs directory found"
     exit 1
   fi

   # Initialize language directory variables
   ESLINT_STANDARDS_DIR=""
   PYTHON_STANDARDS_DIR=""
   PHP_STANDARDS_DIR=""
   RUST_STANDARDS_DIR=""
   JAVA_STANDARDS_DIR=""
   
   # Discover language directories
   DISCOVERED_LANGUAGES=""
   if [ -d "$CONFIGS_BASE_DIR" ]; then
       for lang_dir in "$CONFIGS_BASE_DIR"/*/ ; do
           if [ -d "$lang_dir" ]; then
               lang_name=$(basename "$lang_dir")
               DISCOVERED_LANGUAGES="$DISCOVERED_LANGUAGES $lang_name"
               
               # Set directory variables based on language
               case "$lang_name" in
                   "eslint")
                       ESLINT_STANDARDS_DIR="$lang_dir"
                       ESLINT_CONFIG_PATH="$lang_dir/eslint.config.js"
                       ;;
                   "python")
                       PYTHON_STANDARDS_DIR="$lang_dir"
                       PYTHON_TOML_CONFIG_PATH="$lang_dir/pyproject.toml"
                       PYTHON_FLAKE8_CONFIG_PATH="$lang_dir/.flake8"
                       ;;
                   "php")
                       PHP_STANDARDS_DIR="$lang_dir"
                       PHP_CONFIG_PATH="$lang_dir/phpcs.xml"
                       PHP_STAN_CONFIG_PATH="$lang_dir/phpstan.neon"
                       ;;
                   "rust")
                       RUST_STANDARDS_DIR="$lang_dir"
                       RUST_FMT_CONFIG_PATH="$lang_dir/rustfmt.toml"
                       RUST_CLIPPY_CONFIG_PATH="$lang_dir/clippy.toml"
                       ;;
                   "java")
                       JAVA_STANDARDS_DIR="$lang_dir"
                       JAVA_CHECKSTYLE_CONFIG_PATH="$lang_dir/checkstyle.xml"
                       JAVA_SPOTBUGS_CONFIG_PATH="$lang_dir/spotbugs.xml"
                       ;;
               esac
           fi
       done
   fi
   
   # Set up common paths (repos folder should never have .vscode)
   # Individual repositories cloned into repos/ will bring their own .vscode if needed

   echo "Discovered language configurations:"
   for lang in $DISCOVERED_LANGUAGES; do
       case "$lang" in
           "eslint") echo "   eslint: $ESLINT_STANDARDS_DIR" ;;
           "python") echo "   python: $PYTHON_STANDARDS_DIR" ;;
           "php") echo "   php: $PHP_STANDARDS_DIR" ;;
           "rust") echo "   rust: $RUST_STANDARDS_DIR" ;;
           "java") echo "   java: $JAVA_STANDARDS_DIR" ;;
           *) echo "   $lang: $CONFIGS_BASE_DIR/$lang" ;;
       esac
   done
   
   if [ -z "$DISCOVERED_LANGUAGES" ]; then
       echo "Warning: No language directories found in $CONFIGS_BASE_DIR"
   fi
}

# Get directory path for a specific language (bash 3.x compatible)
get_language_dir() {
    local language="$1"
    case "$language" in
        "eslint") echo "$ESLINT_STANDARDS_DIR" ;;
        "python") echo "$PYTHON_STANDARDS_DIR" ;;
        "php") echo "$PHP_STANDARDS_DIR" ;;
        "rust") echo "$RUST_STANDARDS_DIR" ;;
        "java") echo "$JAVA_STANDARDS_DIR" ;;
        *) echo "$CONFIGS_BASE_DIR/$language" ;;
    esac
}

# Get config path for a specific language and config type (bash 3.x compatible)
get_language_config() {
    local config_key="$1"
    case "$config_key" in
        "eslint_config") echo "$ESLINT_CONFIG_PATH" ;;
        "python_toml") echo "$PYTHON_TOML_CONFIG_PATH" ;;
        "python_flake8") echo "$PYTHON_FLAKE8_CONFIG_PATH" ;;
        "php_config") echo "$PHP_CONFIG_PATH" ;;
        "php_stan") echo "$PHP_STAN_CONFIG_PATH" ;;
        "rust_fmt") echo "$RUST_FMT_CONFIG_PATH" ;;
        "rust_clippy") echo "$RUST_CLIPPY_CONFIG_PATH" ;;
        "java_checkstyle") echo "$JAVA_CHECKSTYLE_CONFIG_PATH" ;;
        "java_spotbugs") echo "$JAVA_SPOTBUGS_CONFIG_PATH" ;;
        *) echo "" ;;
    esac
}

# List all discovered languages (bash 3.x compatible)
list_available_languages() {
    echo "Available languages:$DISCOVERED_LANGUAGES"
    for lang in $DISCOVERED_LANGUAGES; do
        echo "  - $lang"
    done
}

# Main setup function that other scripts can call
setup_amphora_environment() {
    echo -e "${BLUE}Setting up Amphora development environment${NC}"
    
    detect_os
    get_current_dir
    detect_target_folder
    copy_standards_dir_to_desktop
    setup_directory_paths
    
    echo -e "${GREEN}Amphora environment setup complete!${NC}"
    echo "Standards directory: $ROOT_STANDARDS_DIR"
}

# If script is run directly, execute main setup
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_amphora_environment
fi