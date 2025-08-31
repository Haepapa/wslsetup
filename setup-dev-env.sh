#!/bin/bash

# Ubuntu WSL Development Environment Setup Script
# This script sets up a complete development environment on Ubuntu under WSL
# Requires sudo privileges to run and reads configuration from config.yml

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

# Get the original user (not root)
ORIGINAL_USER=${SUDO_USER:-$(whoami)}
ORIGINAL_HOME=$(eval echo ~$ORIGINAL_USER)

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yml"

log_info "Setting up development environment for user: $ORIGINAL_USER"
log_info "User home directory: $ORIGINAL_HOME"
log_info "Script directory: $SCRIPT_DIR"

#==============================================================================
# CONFIGURATION VALIDATION
#==============================================================================
log_info "Validating configuration..."

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "Configuration file not found: $CONFIG_FILE"
    log_error "Please ensure config.yml exists in the same directory as this script"
    exit 1
fi

# Install yq for YAML parsing if not available
if ! command -v yq &> /dev/null; then
    log_info "Installing yq for YAML parsing..."
    wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq
fi

# Function to check if a config value exists and is true
config_enabled() {
    local path="$1"
    local value=$(yq eval ".$path" "$CONFIG_FILE" 2>/dev/null)
    
    if [[ "$value" == "null" ]]; then
        log_error "Configuration missing for: $path"
        log_error "Please add '$path: true/false' to $CONFIG_FILE"
        exit 1
    fi
    
    [[ "$value" == "true" ]]
}

# Function to validate all required config entries exist
validate_config() {
    local missing_configs=()
    
    # Define all software that the script can install
    local required_configs=(
        "system.update_packages"
        "system.upgrade_packages"
        "system.install_essentials"
        "python.uv"
        "go.gvm"
        "nodejs.nvm"
        "editors.vscode_code_command"
    )
    
    # Check each required config
    for config in "${required_configs[@]}"; do
        local value=$(yq eval ".$config" "$CONFIG_FILE" 2>/dev/null)
        if [[ "$value" == "null" ]]; then
            missing_configs+=("$config")
        fi
    done
    
    # If any configs are missing, error out
    if [[ ${#missing_configs[@]} -gt 0 ]]; then
        log_error "Missing required configuration entries in $CONFIG_FILE:"
        for config in "${missing_configs[@]}"; do
            log_error "  - $config"
        done
        log_error ""
        log_error "Please add all missing entries to your config.yml file."
        log_error "Each entry should be set to either 'true' or 'false'."
        exit 1
    fi
}

# Validate configuration
validate_config
log_success "Configuration validated successfully"

#==============================================================================
# STEP 1: Update and Upgrade Ubuntu
#==============================================================================

# Update package lists
if config_enabled "system.update_packages"; then
    log_info "Step 1a: Updating Ubuntu package lists..."
    apt update -y
    log_success "Package lists updated successfully"
else
    log_warning "Skipping package list update (disabled in config)"
fi

# Upgrade installed packages
if config_enabled "system.upgrade_packages"; then
    log_info "Step 1b: Upgrading installed packages..."
    apt upgrade -y
    log_success "Packages upgraded successfully"
else
    log_warning "Skipping package upgrade (disabled in config)"
fi

# Install essential build tools and dependencies
if config_enabled "system.install_essentials"; then
    log_info "Step 1c: Installing essential build tools and dependencies..."
    apt install -y \
        curl \
        wget \
        git \
        build-essential \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        unzip \
        zip \
        jq
    log_success "Essential packages installed successfully"
else
    log_warning "Skipping essential packages installation (disabled in config)"
fi

#==============================================================================
# STEP 2: Install uv (Python package manager)
#==============================================================================
if config_enabled "python.uv"; then
    log_info "Step 2: Installing uv..."
    
    # Install uv using the official installer
    curl -LsSf https://astral.sh/uv/install.sh | sudo -u $ORIGINAL_USER sh
    
    # Add uv to PATH for the user
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> $ORIGINAL_HOME/.bashrc
    
    log_success "uv installed successfully"
else
    log_warning "Skipping uv installation (disabled in config)"
fi

#==============================================================================
# STEP 3: Install gvm (Go Version Manager)
#==============================================================================
if config_enabled "go.gvm"; then
    log_info "Step 3: Installing gvm (Go Version Manager)..."
    
    # Install dependencies for gvm
    apt install -y bison
    
    # Install gvm as the original user
    sudo -u $ORIGINAL_USER bash << EOF
        # Download and install gvm
        bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
        
        # Source gvm in bashrc if not already present
        if ! grep -q "source.*gvm" $ORIGINAL_HOME/.bashrc; then
            echo 'source $HOME/.gvm/scripts/gvm' >> $ORIGINAL_HOME/.bashrc
        fi
EOF
    
    log_success "gvm installed successfully"
else
    log_warning "Skipping gvm installation (disabled in config)"
fi

#==============================================================================
# STEP 4: Install nvm (Node Version Manager)
#==============================================================================
if config_enabled "nodejs.nvm"; then
    log_info "Step 4: Installing nvm (Node Version Manager)..."
    
    # Install nvm as the original user
    sudo -u $ORIGINAL_USER bash << EOF
        # Download and install nvm
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        
        # The install script automatically adds nvm to .bashrc, but let's verify
        if ! grep -q "NVM_DIR" $ORIGINAL_HOME/.bashrc; then
            echo 'export NVM_DIR="$HOME/.nvm"' >> $ORIGINAL_HOME/.bashrc
            echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> $ORIGINAL_HOME/.bashrc
            echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> $ORIGINAL_HOME/.bashrc
        fi
EOF
    
    log_success "nvm installed successfully"
else
    log_warning "Skipping nvm installation (disabled in config)"
fi

#==============================================================================
# STEP 5: Setup VS Code 'code' command in WSL
#==============================================================================
if config_enabled "editors.vscode_code_command"; then
    log_info "Step 5: Setting up VS Code 'code' command in WSL..."

    # Use proper PowerShell syntax with -Command parameter
    WIN_USER=$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0//powershell.exe -Command "Write-Output \$env:UserName" 2>/dev/null | tr -d '\r\n' || true)
    if [[ -z "$WIN_USER" ]]; then
        log_error "Could not determine Windows username using powershell.exe."
        log_warning "Try running 'powershell.exe -Command \"Write-Output \\\$env:UserName\"' in your WSL terminal to debug."
    fi

    if [[ -z "$WIN_USER" ]]; then
        log_error "Aborting VS Code command setup due to missing Windows username."
    else
        log_info "Detected Windows username: $WIN_USER"

        # Run code . to trigger VS Code server install (as original user)
        if ! 'code . || true'; then
            log_warning "The 'code .' command did not run successfully. Ensure VS Code is installed on Windows and available in PATH."
        fi

        # Add code function to .bashrc if not already present
        if ! grep -q "/mnt/c/Users/$WIN_USER/AppData/Local/Programs/Microsoft\\ VS\\ Code/Code.exe" $ORIGINAL_HOME/.bashrc; then
            echo "function code () {" >> $ORIGINAL_HOME/.bashrc
            echo "  /mnt/c/Users/$WIN_USER/AppData/Local/Programs/Microsoft\\ VS\\ Code/Code.exe \"\$@\";" >> $ORIGINAL_HOME/.bashrc
            echo "}" >> $ORIGINAL_HOME/.bashrc
        else
            log_info "VS Code bash function already present in .bashrc."
        fi

        # Source .bashrc and run code . again (as original user)
        if ! sudo -u $ORIGINAL_USER bash -c "source $ORIGINAL_HOME/.bashrc && code . || true"; then
            log_warning "The 'code' bash function did not run successfully after updating .bashrc. Check your .bashrc and VS Code installation."
        fi

        # Check if the code function is now available
        if sudo -u $ORIGINAL_USER bash -c "type code &>/dev/null"; then
            log_success "VS Code 'code' command setup completed."
        else
            log_warning "VS Code 'code' command function was added, but is not available in the current shell. Try opening a new terminal or run: source ~/.bashrc"
        fi
    fi
else
    log_warning "Skipping VS Code 'code' command setup (disabled in config)"
fi
#==============================================================================
# FINALISATION
#==============================================================================
log_info "Finalising setup..."

# Set proper ownership of user files (in case any were created as root)
chown -R $ORIGINAL_USER:$ORIGINAL_USER $ORIGINAL_HOME/.local 2>/dev/null || true
chown -R $ORIGINAL_USER:$ORIGINAL_USER $ORIGINAL_HOME/.gvm 2>/dev/null || true
chown -R $ORIGINAL_USER:$ORIGINAL_USER $ORIGINAL_HOME/.nvm 2>/dev/null || true
chown $ORIGINAL_USER:$ORIGINAL_USER $ORIGINAL_HOME/.bashrc 2>/dev/null || true

log_success "Development environment setup completed!"
echo ""
log_info "=== NEXT STEPS ==="
log_warning "Please restart your terminal or run: source ~/.bashrc"
log_info "Then you can use:"
log_info "  • uv --help       (Python package management)"
log_info "  • gvm list        (Go version management)"
log_info "  • nvm --help      (Node.js version management)"
echo ""
log_info "To install specific versions:"
log_info "  • gvm install go1.21.0 && gvm use go1.21.0 --default"
log_info "  • nvm install node && nvm use node"


#==============================================================================
# EXTENSIBILITY SECTION
#==============================================================================
# ADD NEW SOFTWARE INSTALLATIONS BELOW THIS LINE
# 
# IMPORTANT: When adding new software, you MUST:
# 1. Add the configuration entry to config.yml
# 2. Add the config path to the required_configs array in validate_config()
# 3. Use the config_enabled() function to check if installation should proceed
# 
# Template for adding new software:
# 
# #==============================================================================
# # STEP X: Install [SOFTWARE_NAME]
# #==============================================================================
# if config_enabled "category.software_name"; then
#     log_info "Step X: Installing [SOFTWARE_NAME]..."
#     
#     # Installation commands here
#     # Remember to use sudo -u $ORIGINAL_USER for user-specific installations
#     
#     log_success "[SOFTWARE_NAME] installed successfully"
# else
#     log_warning "Skipping [SOFTWARE_NAME] installation (disabled in config)"
# fi

# Examples:
#
# Docker (add "containers.docker: true/false" to config.yml):
# if config_enabled "containers.docker"; then
#     log_info "Installing Docker..."
#     apt install -y docker.io
#     usermod -aG docker $ORIGINAL_USER
#     systemctl enable docker
#     log_success "Docker installed successfully"
# else
#     log_warning "Skipping Docker installation (disabled in config)"
# fi
#
# VSCode (add "editors.vscode: true/false" to config.yml):
# if config_enabled "editors.vscode"; then
#     log_info "Installing VSCode..."
#     snap install code --classic
#     log_success "VSCode installed successfully"
# else
#     log_warning "Skipping VSCode installation (disabled in config)"
# fi
#
# Additional Python versions (add "languages.python311: true/false" to config.yml):
# if config_enabled "languages.python311"; then
#     log_info "Installing Python 3.11..."
#     add-apt-repository ppa:deadsnakes/ppa -y
#     apt update
#     apt install -y python3.11 python3.11-venv python3.11-dev
#     log_success "Python 3.11 installed successfully"
# else
#     log_warning "Skipping Python 3.11 installation (disabled in config)"
# fi
