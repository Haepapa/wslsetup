# Ubuntu WSL Development Environment Setup

This repository contains an automated setup script for configuring Ubuntu under WSL (Windows Subsystem for Linux) as a complete software development environment.

## 🚀 Quick Start

1. Clone or download this repository
2. (Optional) Customise `config.yml` to enable/disable specific software
3. Make the script executable (if not already): `chmod +x setup-dev-env.sh`
4. Run the setup script with sudo: `sudo ./setup-dev-env.sh`
5. Restart your terminal or run `source ~/.bashrc` to load the new environment

## 📦 What Gets Installed

The setup script automatically installs and configures:

### System Updates
- Updates Ubuntu package lists
- Upgrades all installed packages
- Installs essential build tools and dependencies

### Development Tools
- **uv** - Modern Python package and project manager
- **gvm** - Go Version Manager for managing multiple Go versions
- **nvm** - Node Version Manager for managing multiple Node.js versions

### Supporting Packages
- `curl`, `wget` - For downloading files
- `git` - Version control
- `build-essential` - Compilation tools (gcc, make, etc.)
- `jq` - JSON processor
- `zip`, `unzip` - Archive utilities
- Various certificates and transport packages

## 🛠️ Usage

### Running the Setup Script

```bash
# Make executable (if needed)
chmod +x setup-dev-env.sh

# Run with sudo
sudo ./setup-dev-env.sh
```

The script requires no user interaction and will complete automatically.

### After Installation

Once the script completes, restart your terminal or source your bashrc:

```bash
source ~/.bashrc
```

Then you can use the installed tools:

```bash
# Python with uv
uv --help
uv init my-project
uv add requests

# Go with gvm
gvm list
gvm install go1.21.0
gvm use go1.21.0 --default

# Node.js with nvm
nvm --help
nvm install node
nvm use node
```

## ⚙️ Configuration

The setup script uses a YAML configuration file (`config.yml`) to control which software gets installed. This allows you to customise your development environment without modifying the script itself.

### Configuration File Structure

The `config.yml` file is organised into categories:

```yaml
# Core system updates (recommended to keep enabled)
system:
  update_packages: true      # Update Ubuntu package lists
  upgrade_packages: true     # Upgrade installed packages
  install_essentials: true   # Install build-essential, curl, wget, git, etc.

# Python development
python:
  uv: true                   # Modern Python package and project manager

# Go development
go:
  gvm: true                  # Go Version Manager

# Node.js development
nodejs:
  nvm: true                  # Node Version Manager
```

### Configuration Rules

- **All software must be listed**: Every piece of software that can be installed by the script MUST have a corresponding entry in `config.yml`
- **Validation enforced**: The script will error if any installable software is missing from the config
- **Boolean values only**: Each entry must be set to either `true` (install) or `false` (skip)
- **Required for extensibility**: When adding new software, you must add its config entry

### Customising Your Installation

1. **Edit config.yml** before running the script
2. **Set to `false`** any software you don't want installed
3. **Keep `true`** for software you want installed
4. **System updates** are recommended to keep enabled for security

### Example: Minimal Installation

```yaml
system:
  update_packages: true
  upgrade_packages: true
  install_essentials: true

python:
  uv: false                  # Skip Python tools

go:
  gvm: true                  # Only install Go

nodejs:
  nvm: false                 # Skip Node.js tools
```

## 🔧 Adding New Software

To add new software to the setup script:

### Step 1: Add Configuration Entry

First, add the software to `config.yml`:

```yaml
# Add to appropriate category or create new one
containers:
  docker: true               # Enable Docker installation
```

### Step 2: Update Script Validation

Add the config path to the `required_configs` array in the `validate_config()` function:

```bash
local required_configs=(
    "system.update_packages"
    "system.upgrade_packages"
    "system.install_essentials"
    "python.uv"
    "go.gvm"
    "nodejs.nvm"
    "containers.docker"        # Add your new software here
)
```

### Step 3: Add Installation Logic

Use the provided template in the extensibility section:

```bash
#==============================================================================
# STEP X: Install Docker
#==============================================================================
if config_enabled "containers.docker"; then
    log_info "Step X: Installing Docker..."
    
    # Installation commands here
    apt install -y docker.io
    usermod -aG docker $ORIGINAL_USER
    systemctl enable docker
    
    log_success "Docker installed successfully"
else
    log_warning "Skipping Docker installation (disabled in config)"
fi
```

### Template Guidelines

- **Use `config_enabled()`** to check if software should be installed
- **Use proper user context** - use `sudo -u $ORIGINAL_USER` for user-specific installations
- **Add logging** using the provided log functions for consistent output
- **Handle ownership** - ensure files have correct user ownership
- **Provide skip message** when software is disabled in config

## 🔍 Troubleshooting

### Permission Issues
If you encounter permission errors:
- Ensure you're running the script with `sudo`
- The script automatically handles user/root context switching

### Missing Dependencies
If installations fail due to missing dependencies:
- The script installs common build tools, but some software may need additional packages
- Add any additional `apt install` commands in the appropriate section

### Path Issues
If tools aren't found after installation:
- Restart your terminal or run `source ~/.bashrc`
- Check that the PATH exports were added correctly to your `.bashrc`

### Configuration Issues
If you get configuration validation errors:
- **Missing config entries**: Add the missing entries to `config.yml` with `true` or `false` values
- **Invalid YAML**: Check your YAML syntax - indentation must be consistent, use spaces not tabs
- **Config file not found**: Ensure `config.yml` exists in the same directory as the script

### WSL-Specific Issues
- Ensure WSL is properly configured and updated
- Some features may require WSL 2 for full functionality

## 📋 Script Features

- **Error handling** - Script stops on any error (`set -e`)
- **User context management** - Properly handles sudo vs regular user operations
- **Colored output** - Clear, colored logging for better readability
- **Ownership management** - Ensures files have correct ownership
- **Non-interactive** - Runs completely unattended
- **Extensible design** - Easy to add new software installations

## 🔄 Version Managers Usage

### uv (Python)
```bash
# Create a new project
uv init my-python-project
cd my-python-project

# Add dependencies
uv add requests pandas

# Run Python
uv run python script.py
```

### gvm (Go)
```bash
# List available Go versions
gvm listall

# Install and use a specific Go version
gvm install go1.21.0
gvm use go1.21.0 --default

# Verify installation
go version
```

### nvm (Node.js)
```bash
# List available Node versions
nvm list-remote

# Install latest LTS Node.js
nvm install --lts
nvm use --lts

# Install specific version
nvm install 18.17.0
nvm use 18.17.0

# Verify installation
node --version
npm --version
```

## 📝 Notes

- This script is designed specifically for Ubuntu under WSL
- All installations are done in a way that preserves user permissions
- The script can be run multiple times safely (idempotent where possible)
- Version managers are installed to allow easy switching between language versions

## 🤝 Contributing

To contribute improvements or add support for additional software:

1. Fork this repository
2. Add your changes following the established patterns
3. Test on a clean Ubuntu WSL instance
4. Submit a pull request with a clear description

## 📄 License

This project is open source. Feel free to use, modify, and distribute as needed.
