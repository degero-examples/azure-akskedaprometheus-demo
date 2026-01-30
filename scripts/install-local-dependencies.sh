#!/bin/bash

check_and_install_command() {
    local cmd=$1
    local install_cmd=$2
    local win_install_cmd=$3
    
    if ! command -v "$cmd" &> /dev/null; then
        echo "Installing Dependency: $cmd..."
        os=$(echo `uname`|tr '[:upper:]' '[:lower:]')
        case "$os" in
            linux)
                # Linux (including WSL)
                if [ "$cmd" = "helm" ]; then
                    sudo apt-get update && sudo apt-get install -y curl
                    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
                    chmod 700 get_helm.sh
                    ./get_helm.sh
                else
                    if [[ -f /etc/os-release ]]; then
                    . /etc/os-release
                    case $ID in
                        ubuntu|debian|linuxmint)
                            echo "Detected Debian-based distro ($ID). Installing with apt..."
                            sudo apt update && sudo apt install -y "$package"
                            ;;
                        fedora)
                            echo "Detected Fedora. Installing with dnf..."
                            sudo dnf install -y "$package"
                            ;;
                        centos|rhel|rocky)
                            echo "Detected RHEL/CentOS-based distro ($ID). Installing with dnf..."
                            sudo dnf install -y "$package"
                            ;;
                        arch|manjaro)
                            echo "Detected Arch-based distro ($ID). Installing with pacman..."
                            sudo pacman -S --noconfirm "$package"
                            ;;
                        opensuse*|sles)
                            echo "Detected SUSE-based distro ($ID). Installing with zypper..."
                            sudo zypper install -y "$package"
                            ;;
                        alpine)
                            echo "Detected Alpine. Installing with apk..."
                            sudo apk add "$package"
                            ;;
                        *)
                            echo "Unsupported Linux distro: $ID. Please install $package manually."
                            ;;
                    esac
                    else
                        echo "Cannot detect Linux distro (/etc/os-release not found). Skipping"
                    fi
                fi
                ;;
            darwin)
                # macOS
                brew install "$install_cmd"
                ;;
            cygwin*|mingw*|msys*)
                # Windows (Git Bash, etc.)
                winget install "$win_install_cmd" --accept-package-agreements
                ;;
            *)
                echo "Unsupported OS: $os"
                ;;
        esac
    else
        echo "$cmd is already installed."
    fi
}

check_and_install_command "helm" "helm" "Helm.Helm"
check_and_install_command "kubectl" "kubectl" "kubectl"
