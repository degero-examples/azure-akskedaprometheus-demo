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
                    sudo apt-get update && sudo apt-get install -y "$install_cmd"
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
