#!/bin/bash

# Dependency Checker for K8Agent Project
# Validates all required tools are installed and provides installation guidance

echo "🔍 Checking K8Agent Dependencies..."
echo "=================================="

# Track if any dependencies are missing
MISSING_DEPS=0

# Function to check if command exists
check_command() {
    local cmd=$1
    local name=$2
    local install_hint=$3
    
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "✅ $name: $(command -v "$cmd")"
        if [ "$cmd" = "node" ]; then
            local version=$(node --version)
            local major_version=$(echo "$version" | sed 's/v\([0-9]*\).*/\1/')
            if [ "$major_version" -lt 18 ]; then
                echo "   ⚠️  Warning: Node.js version $version detected. Requires v18 or higher."
                MISSING_DEPS=1
            else
                echo "   ✅ Version: $version"
            fi
        fi
    else
        echo "❌ $name: Not found"
        echo "   💡 Install: $install_hint"
        MISSING_DEPS=1
    fi
}

# Check Docker
check_command "docker" "Docker" "https://docs.docker.com/get-docker/"

# Check Node.js
check_command "node" "Node.js" "https://nodejs.org/ (v18 or higher)"

# Check kubectl
check_command "kubectl" "kubectl" "https://kubernetes.io/docs/tasks/tools/"

# Check curl
check_command "curl" "curl" "Usually pre-installed on macOS/Linux"

# Check jq
check_command "jq" "jq" "brew install jq (macOS) or apt install jq (Ubuntu)"

# Check bash
check_command "bash" "bash" "Usually pre-installed on macOS/Linux"

echo ""
echo "=================================="

# Check if Docker is running
if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        echo "✅ Docker daemon: Running"
    else
        echo "⚠️  Docker daemon: Not running"
        echo "   💡 Start Docker Desktop or run: sudo systemctl start docker"
        MISSING_DEPS=1
    fi
fi

# Summary
echo ""
if [ $MISSING_DEPS -eq 0 ]; then
    echo "🎉 All dependencies are satisfied! You're ready to run K8Agent."
    echo ""
    echo "Next steps:"
    echo "1. cd web-app"
    echo "2. npm install"
    echo "3. ./start-monitoring.sh"
else
    echo "⚠️  Some dependencies are missing or need attention."
    echo "   Please install the missing dependencies and run this script again."
fi

exit $MISSING_DEPS
