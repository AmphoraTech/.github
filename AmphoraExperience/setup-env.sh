#!/usr/bin/env bash
set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Initialize flags
ESLINT_FLAG=false
PYTHON_FLAG=false
MAC_TOOLS_FLAG=false
LINUX_TOOLS_FLAG=false
AWS_CERTIFICATES_FLAG=false
GIT_CERTIFICATES_FLAG=false
FULL_FLAG=false

# ---- Ensure commands are installed ----
require_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: required command '$1' not found. Install it and re-run." >&2
    exit 1
  fi
}

# ---- Enhanced OS detection ----
detect_os() {
   if [[ "$OSTYPE" == "darwin"* ]]; then
      OS_TYPE="macos"
      HOME_DIR="$HOME"
      DESKTOP_PATH="$HOME_DIR/Desktop"
      VSCODE_USER_DIR="$HOME_DIR/Library/Application Support/Code/User"
      CURSOR_USER_DIR="$HOME_DIR/Library/Application Support/Cursor/User"
      echo "Detected OS: macOS"
   elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      OS_TYPE="linux"
      HOME_DIR="$HOME"
      DESKTOP_PATH="$HOME_DIR/Desktop"
      VSCODE_USER_DIR="$HOME_DIR/.config/Code/User"
      CURSOR_USER_DIR="$HOME_DIR/.config/Cursor/User"
      echo "Detected OS: Linux"
   elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
      OS_TYPE="windows"
      HOME_DIR="$USERPROFILE"
      DESKTOP_PATH="$HOME_DIR/Desktop"
      VSCODE_USER_DIR="$HOME_DIR/AppData/Roaming/Code/User"
      CURSOR_USER_DIR="$HOME_DIR/AppData/Roaming/Cursor/User"
      echo "Detected OS: Windows"
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
  if [ -d "$CURRENT_DIR/repos" ] && ([ -d "$CURRENT_DIR/configs" ] || [ -d "$CURRENT_DIR/code-standards" ]); then
    echo "Script is inside target folder: $FOLDER_NAME"
    TARGET_FOLDER_PATH="$CURRENT_DIR"
    TARGET_FOLDER_NAME="$FOLDER_NAME"
    return 0
  fi

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

# Copy function (condensed)
copy_standards_dir_to_desktop() {
   ROOT_STANDARDS_DIR="$DESKTOP_PATH/$TARGET_FOLDER_NAME"

   echo "Target folder path: $TARGET_FOLDER_PATH"
   echo "Target desktop path: $ROOT_STANDARDS_DIR"

   if [ "$TARGET_FOLDER_PATH" = "$ROOT_STANDARDS_DIR" ]; then
      echo "Already in correct location: $ROOT_STANDARDS_DIR"
      return 0
   fi

   echo "Copying $TARGET_FOLDER_NAME to desktop..."

   # Detect existing directories to preserve
   EXISTING_DIRS=()
   if [ -d "$ROOT_STANDARDS_DIR" ]; then
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
       cd "$ORIGINAL_GIT_DIR"
       GIT_REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
       GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
   fi

   # Build exclude patterns and perform copy with rsync/cp
   EXCLUDE_PATTERNS=()
   if [ ${#EXISTING_DIRS[@]} -gt 0 ]; then
       for dir in "${EXISTING_DIRS[@]}"; do
           EXCLUDE_PATTERNS+=("--exclude=$dir")
       done
   fi

   if command -v rsync >/dev/null 2>&1; then
       rsync_cmd=(rsync -av)
       
       if [ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]; then
           for pattern in "${EXCLUDE_PATTERNS[@]}"; do
               rsync_cmd+=("$pattern")
           done
       fi
       
       repos_exists=false
       if [ ${#EXISTING_DIRS[@]} -gt 0 ]; then
           for dir in "${EXISTING_DIRS[@]}"; do
               [ "$dir" = "repos" ] && repos_exists=true && break
           done
       fi
       
       [ "$repos_exists" = false ] && rsync_cmd+=(--include='repos/' --include='repos/*.md' --exclude='repos/*')
       
       rsync_cmd+=(
           --exclude='.history/' --exclude='node_modules/' --exclude='package-lock.json'
           --exclude='yarn.lock' --exclude='dist/' --exclude='build/' --exclude='.DS_Store' --exclude='*.sh'
       )
       
       rsync_cmd+=("$TARGET_FOLDER_PATH/" "$ROOT_STANDARDS_DIR/")
       "${rsync_cmd[@]}"
   else
       mkdir -p "$ROOT_STANDARDS_DIR"
       temp_copy_dir=$(mktemp -d)
       cp -r "$TARGET_FOLDER_PATH"/* "$temp_copy_dir/" 2>/dev/null || true
       
       if [ ${#EXISTING_DIRS[@]} -gt 0 ]; then
           for dir in "${EXISTING_DIRS[@]}"; do
               [ -d "$temp_copy_dir/$dir" ] && rm -rf "$temp_copy_dir/$dir"
           done
       fi
       
       # Clean artifacts and copy
       artifacts=('.history' 'node_modules' 'package-lock.json' 'yarn.lock' 'dist' 'build' '.DS_Store')
       for artifact in "${artifacts[@]}"; do
           find "$temp_copy_dir" -name "$artifact" -exec rm -rf {} + 2>/dev/null || true
       done
       find "$temp_copy_dir" -name "*.sh" -exec rm -f {} + 2>/dev/null || true
       
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

   CURRENT_DIR="$ROOT_STANDARDS_DIR"
   TARGET_FOLDER_PATH="$ROOT_STANDARDS_DIR"
}

# Directory paths setup
setup_directory_paths() {
   echo "Detecting directory structure..."
   
   CONFIGS_BASE_DIR=""
   if [ -d "$ROOT_STANDARDS_DIR/code-standards/configs" ]; then
     CONFIGS_BASE_DIR="$ROOT_STANDARDS_DIR/code-standards/configs"
   elif [ -d "$ROOT_STANDARDS_DIR/configs" ]; then
     CONFIGS_BASE_DIR="$ROOT_STANDARDS_DIR/configs"
   elif [ -d "$ROOT_STANDARDS_DIR/code-standards" ]; then
     CONFIGS_BASE_DIR="$ROOT_STANDARDS_DIR/code-standards"
   else
     echo "No valid configs directory found"; exit 1
   fi

   # Initialize language variables
   ESLINT_STANDARDS_DIR=""
   PYTHON_STANDARDS_DIR=""
   DISCOVERED_LANGUAGES=""
   
   if [ -d "$CONFIGS_BASE_DIR" ]; then
       for lang_dir in "$CONFIGS_BASE_DIR"/*/ ; do
           if [ -d "$lang_dir" ]; then
               lang_name=$(basename "$lang_dir")
               DISCOVERED_LANGUAGES="$DISCOVERED_LANGUAGES $lang_name"
               
               case "$lang_name" in
                   "eslint")
                       ESLINT_STANDARDS_DIR="$lang_dir"
                       ESLINT_CONFIG_PATH="$lang_dir/eslint.config.js"
                       ;;
                   "python")
                       PYTHON_STANDARDS_DIR="$lang_dir"
                       PYTHON_TOML_CONFIG_PATH="$lang_dir/pyproject.toml"
                       ;;
               esac
           fi
       done
   fi

   echo "Discovered languages:$DISCOVERED_LANGUAGES"
}

# Install and configure Zsh
install_zsh() {
    echo "Setting up Zsh shell..."
    
    # Install Zsh based on OS
    if [[ "$OS_TYPE" == "macos" ]]; then
        # Zsh is default on macOS 10.15+, but ensure it's updated
        if command -v brew &>/dev/null; then
            brew install zsh zsh-completions || true
        fi
    elif [[ "$OS_TYPE" == "linux" ]]; then
        case $DISTRO in
            "ubuntu"|"debian")
                sudo apt install -y zsh || true
                ;;
            "fedora"|"centos"|"rhel")
                sudo dnf install -y zsh || true
                ;;
            "arch")
                sudo pacman -S --noconfirm zsh || true
                ;;
        esac
    fi
    
    # Install Oh My Zsh if not present
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        
        # Set Zsh as default shell if not already
        if [[ "$SHELL" != *"zsh"* ]]; then
            echo "Setting Zsh as default shell..."
            chsh -s $(which zsh)
            echo "Note: You may need to restart your terminal for shell changes to take effect"
        fi
    else
        echo "Oh My Zsh already installed"
    fi
    
    # Install popular Zsh plugins
    echo "Installing Zsh plugins..."
    
    # zsh-syntax-highlighting
    if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    fi
    
    # zsh-autosuggestions
    if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    fi
    
    # Update .zshrc with recommended plugins
    if [ -f ~/.zshrc ]; then
        # Backup original .zshrc
        cp ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d_%H%M%S)
        
        # Update plugins line if it exists
        if grep -q "^plugins=" ~/.zshrc; then
            sed -i.bak 's/^plugins=(.*)/plugins=(git node npm docker nvm zsh-syntax-highlighting zsh-autosuggestions)/' ~/.zshrc
        else
            # Add plugins line if it doesn't exist
            echo 'plugins=(git node npm docker nvm zsh-syntax-highlighting zsh-autosuggestions)' >> ~/.zshrc
        fi
        
        echo "Updated .zshrc with recommended plugins"
    fi
}

# Install NVM (Node Version Manager)
install_nvm() {
    echo "Installing NVM (Node Version Manager)..."
    
    # Download and install NVM
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    
    # Load NVM for current session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    # Configure for Zsh if it's the current shell
    if [[ "$SHELL" == *"zsh"* ]] || [[ -n "$ZSH_VERSION" ]]; then
        echo "Configuring NVM for Zsh..."
        # Add to .zshrc if not already present
        if ! grep -q "NVM_DIR" ~/.zshrc 2>/dev/null; then
            cat >> ~/.zshrc << 'EOF'

# NVM Configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
        fi
    fi
    
    # Install and use latest LTS Node.js
    if command -v nvm &>/dev/null; then
        echo "Installing Node.js LTS via NVM..."
        nvm install --lts
        nvm use --lts
        nvm alias default lts/*
        echo "Node.js $(node --version) installed and set as default"
    else
        echo "NVM installation may require a new shell session"
        if [[ "$SHELL" == *"zsh"* ]]; then
            echo "Run: source ~/.zshrc && nvm install --lts"
        else
            echo "Run: source ~/.bashrc && nvm install --lts"
        fi
    fi
}

# macOS Tools Installation
install_mac_tools() {
    echo -e "${BLUE}Installing macOS development tools...${NC}"
    
    # Install Homebrew if not present
    if ! command -v brew &>/dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for this session
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        echo "Homebrew already installed"
    fi
    
    # Install and configure Zsh
    install_zsh
    
    # Install NVM instead of Node directly
    if ! command -v nvm &>/dev/null; then
        install_nvm
    else
        echo "NVM already installed"
    fi
    
    # Install Python via Homebrew
    echo "Installing Python..."
    brew install --quiet python@3.11 || true
    
    # Install essential CLI tools
    echo "Installing essential tools..."
    brew install --quiet git curl jq || true
    
    # Install applications via Homebrew Cask
    echo "Installing applications..."
    
    # Development tools
    if ! command -v cursor &>/dev/null; then
        echo "Installing Cursor editor..."
        brew install --cask --quiet cursor || true
    else
        echo "Cursor already installed"
    fi
    
    # Terminal
    if ! ls /Applications/Warp.app >/dev/null 2>&1; then
        echo "Installing Warp terminal..."
        brew install --cask --quiet warp || true
    else
        echo "Warp already installed"
    fi
    
    # Productivity tools
    if ! ls /Applications/Raycast.app >/dev/null 2>&1; then
        echo "Installing Raycast..."
        brew install --cask --quiet raycast || true
    else
        echo "Raycast already installed"
    fi
    
    if ! ls /Applications/Slack.app >/dev/null 2>&1; then
        echo "Installing Slack..."
        brew install --cask --quiet slack || true
    else
        echo "Slack already installed"
    fi
    
    # Docker Desktop
    if ! command -v docker &>/dev/null; then
        echo "Installing Docker Desktop..."
        brew install --cask --quiet docker || true
        echo "Note: You may need to start Docker Desktop manually from Applications"
    else
        echo "Docker already installed"
    fi
    
    echo -e "${GREEN}macOS tools installation complete${NC}"
    echo "Installed applications:"
    echo "  - Zsh with Oh My Zsh + plugins"
    echo "  - NVM (Node Version Manager) with Node.js LTS"
    echo "  - Python 3.11"
    echo "  - Cursor (code editor)"
    echo "  - Warp (terminal)"
    echo "  - Raycast (productivity launcher)"
    echo "  - Slack (team communication)"
    echo "  - Docker Desktop"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  - Restart terminal or run: exec zsh"
    echo "  - Use 'nvm use <version>' to switch Node.js versions"
}

# Linux Tools Installation  
install_linux_tools() {
    echo -e "${BLUE}Installing Linux development tools...${NC}"
    
    # Detect Linux distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        echo "Cannot detect Linux distribution"
        return 1
    fi
    
    # Install and configure Zsh
    install_zsh
    
    # Install NVM first (works across all distributions)
    if ! command -v nvm &>/dev/null; then
        install_nvm
    else
        echo "NVM already installed"
    fi
    
    case $DISTRO in
        "ubuntu"|"debian")
            echo "Detected Ubuntu/Debian system"
            sudo apt update -qq
            
            # Install Python and essential tools (but not Node.js since we use NVM)
            echo "Installing Python and essential tools..."
            sudo apt install -y -qq python3 python3-pip git curl jq docker.io build-essential || true
            
            # Install Cursor (AppImage method for broader compatibility)
            if ! command -v cursor &>/dev/null; then
                echo "Installing Cursor editor..."
                mkdir -p ~/.local/bin
                curl -fL "https://downloader.cursor.sh/linux/appImage/x64" -o ~/.local/bin/cursor.AppImage
                chmod +x ~/.local/bin/cursor.AppImage
                ln -sf ~/.local/bin/cursor.AppImage ~/.local/bin/cursor
                # Add to PATH if not already there
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
            else
                echo "Cursor already installed"
            fi
            
            # Install Warp terminal (if available)
            if ! command -v warp-terminal &>/dev/null; then
                echo "Installing Warp terminal..."
                curl -fsSL https://releases.warp.dev/linux/v0.2024.10.29.08.02.stable_02/warp-terminal_0.2024.10.29.08.02.stable.02_amd64.deb -o warp.deb
                sudo dpkg -i warp.deb || sudo apt-get install -f -y
                rm warp.deb || true
            else
                echo "Warp already installed"
            fi
            
            # Install Slack
            if ! command -v slack &>/dev/null; then
                echo "Installing Slack..."
                wget -O slack.deb https://downloads.slack-edge.com/releases/linux/4.34.121/prod/x64/slack-desktop-4.34.121-amd64.deb
                sudo dpkg -i slack.deb || sudo apt-get install -f -y
                rm slack.deb
            else
                echo "Slack already installed"
            fi
            ;;
            
        "fedora"|"centos"|"rhel")
            echo "Detected Red Hat based system"
            
            # Install Python and tools (NVM handles Node.js)
            sudo dnf install -y python3 python3-pip git curl jq docker gcc gcc-c++ make || true
            
            # Install applications via package manager or manual download
            echo "Installing development applications..."
            
            # Cursor (AppImage)
            if ! command -v cursor &>/dev/null; then
                mkdir -p ~/.local/bin
                curl -fL "https://downloader.cursor.sh/linux/appImage/x64" -o ~/.local/bin/cursor.AppImage
                chmod +x ~/.local/bin/cursor.AppImage
                ln -sf ~/.local/bin/cursor.AppImage ~/.local/bin/cursor
            fi
            
            # Install Slack (RPM)
            if ! command -v slack &>/dev/null; then
                sudo dnf install -y https://downloads.slack-edge.com/releases/linux/4.34.121/prod/x64/slack-4.34.121-0.1.el8.x86_64.rpm || true
            fi
            ;;
            
        "arch")
            echo "Detected Arch Linux"
            sudo pacman -Syu --noconfirm
            sudo pacman -S --noconfirm python python-pip git curl jq docker base-devel || true
            
            # Install AUR packages (if yay is available)
            if command -v yay &>/dev/null; then
                echo "Installing AUR packages..."
                yay -S --noconfirm cursor-bin slack-desktop warp-terminal-bin || true
            else
                echo "Install cursor, slack, and warp manually from AUR"
            fi
            ;;
            
        *)
            echo "Unsupported Linux distribution: $DISTRO"
            echo "Please install manually:"
            echo "  - Python 3, git, curl, jq, docker"
            echo "  - Cursor editor, Warp terminal, Slack"
            ;;
    esac
    
    # Enable Docker service
    sudo systemctl enable docker 2>/dev/null || true
    sudo systemctl start docker 2>/dev/null || true
    sudo usermod -aG docker $USER 2>/dev/null || true
    
    echo -e "${GREEN}Linux tools installation complete${NC}"
    echo "Installed tools:"
    echo "  - Zsh with Oh My Zsh + plugins"
    echo "  - NVM (Node Version Manager) with Node.js LTS"
    echo "  - Python 3"  
    echo "  - Cursor (code editor)"
    echo "  - Warp (terminal) - if supported on your distribution"
    echo "  - Slack (team communication)"
    echo "  - Docker"
    echo ""
    echo -e "${YELLOW}Notes:${NC}"
    echo "  - You may need to log out and back in for Docker group changes"
    echo "  - Restart terminal or run: exec zsh to use new shell"
    echo "  - Cursor installed in ~/.local/bin - ensure it's in your PATH"
    echo "  - Use 'nvm use <version>' to switch Node.js versions"
}

# Language-specific installations
install_eslint() {
    echo -e "${BLUE}Setting up ESLint configuration...${NC}"
    
    if [ -d "$ESLINT_STANDARDS_DIR" ]; then
        cd "$ESLINT_STANDARDS_DIR"
        if [ -f "package.json" ]; then
            # Use npm if available (from NVM), otherwise warn
            if command -v npm &>/dev/null; then
                npm install
                echo "ESLint dependencies installed"
            else
                echo "Warning: npm not found. Install Node.js via NVM first"
                echo "Run: nvm install --lts && nvm use --lts"
            fi
        fi
        cd "$ROOT_STANDARDS_DIR"
    fi
}

install_python() {
    echo -e "${BLUE}Setting up Python configuration...${NC}"
    
    if [ -d "$PYTHON_STANDARDS_DIR" ]; then
        echo "Python configuration found at: $PYTHON_STANDARDS_DIR"
        # Future: Install Python linting tools
        echo "Python setup placeholder - ready for implementation"
    fi
}

# Certificate placeholders
setup_aws_certificates() {
    echo -e "${BLUE}Setting up AWS certificates...${NC}"
    echo "AWS certificates setup placeholder - ready for implementation"
}

setup_git_certificates() {
    echo -e "${BLUE}Setting up Git certificates...${NC}" 
    echo "Git certificates setup placeholder - ready for implementation"
}

# Parse command line arguments
parse_arguments() {
    if [ $# -eq 0 ]; then
        echo "Usage: $0 [OPTIONS]"
        echo "Options:"
        echo "  --eslint           Setup ESLint configuration"
        echo "  --python           Setup Python configuration"
        echo "  --mac-tools        Install macOS development tools (Homebrew, Zsh, NVM, Cursor, Docker, etc.)"
        echo "  --linux-tools      Install Linux development tools (Zsh, NVM, Cursor, Docker, etc.)"
        echo "  --aws-certificates Setup AWS certificates"
        echo "  --git-certificates Setup Git certificates"
        echo "  --full             Complete setup (all components)"
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --eslint) ESLINT_FLAG=true ;;
            --python) PYTHON_FLAG=true ;;
            --mac-tools) MAC_TOOLS_FLAG=true ;;
            --linux-tools) LINUX_TOOLS_FLAG=true ;;
            --aws-certificates) AWS_CERTIFICATES_FLAG=true ;;
            --git-certificates) GIT_CERTIFICATES_FLAG=true ;;
            --full) FULL_FLAG=true ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help to see available options"
                exit 1
                ;;
        esac
        shift
    done
}

# Main execution
main() {
    echo -e "${BLUE}Amphora Development Environment Setup${NC}"
    
    parse_arguments "$@"
    
    # Core setup (always runs)
    detect_os
    get_current_dir
    detect_target_folder
    copy_standards_dir_to_desktop
    setup_directory_paths
    
    echo -e "${GREEN}Core environment setup complete${NC}"
    
    # Handle --full flag
    if [ "$FULL_FLAG" = true ]; then
        ESLINT_FLAG=true
        PYTHON_FLAG=true
        AWS_CERTIFICATES_FLAG=true
        GIT_CERTIFICATES_FLAG=true
        
        # Set OS-specific tools based on detected OS
        if [ "$OS_TYPE" = "macos" ]; then
            MAC_TOOLS_FLAG=true
        elif [ "$OS_TYPE" = "linux" ]; then
            LINUX_TOOLS_FLAG=true
        fi
    fi
    
    # Execute based on flags
    [ "$ESLINT_FLAG" = true ] && install_eslint
    [ "$PYTHON_FLAG" = true ] && install_python
    [ "$MAC_TOOLS_FLAG" = true ] && install_mac_tools
    [ "$LINUX_TOOLS_FLAG" = true ] && install_linux_tools
    [ "$AWS_CERTIFICATES_FLAG" = true ] && setup_aws_certificates
    [ "$GIT_CERTIFICATES_FLAG" = true ] && setup_git_certificates
    
    echo ""
    echo -e "${GREEN}Setup completed successfully!${NC}"
    echo "Environment location: $ROOT_STANDARDS_DIR"
    echo ""
    echo "Next steps:"
    echo "  1. Restart your terminal or run: exec zsh"
    echo "  2. Clone your repositories: cd $ROOT_STANDARDS_DIR/repos & git clone <your-repo-url>"
    echo "  3. Each repository will use the shared ESLint config automatically"
    echo "  4. Individual repositories can have their own .vscode settings if needed"
    echo "  5. Use 'nvm list' to see installed Node.js versions"
    echo "  6. Use 'nvm use <version>' to switch Node.js versions"
    echo "  7. Start developing with shared configurations"
}

# Execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi