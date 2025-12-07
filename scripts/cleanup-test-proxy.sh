#!/bin/bash

set -e

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROXY_CONTAINER_NAME="test-corporate-proxy"
SQUID_CONFIG_DIR="${PROJECT_ROOT}/test-proxy"

echo -e "${GREEN}=== Test Proxy Cleanup ===${NC}"
echo ""

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Stop and remove proxy container
cleanup_container() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${PROXY_CONTAINER_NAME}$"; then
        print_info "Stopping and removing proxy container..."
        docker stop ${PROXY_CONTAINER_NAME} 2>/dev/null || true
        docker rm ${PROXY_CONTAINER_NAME} 2>/dev/null || true
        print_success "Proxy container removed ✓"
    else
        print_info "No proxy container found"
    fi
}

# Remove configuration directory
cleanup_config() {
    if [ -d "${SQUID_CONFIG_DIR}" ]; then
        print_info "Removing Squid configuration directory..."
        rm -rf "${SQUID_CONFIG_DIR}"
        print_success "Configuration directory removed ✓"
    else
        print_info "No configuration directory found"
    fi
}

# Optionally remove proxy.env
cleanup_proxy_env() {
    if [ -f "${PROJECT_ROOT}/proxy/proxy.env" ]; then
        read -p "Remove proxy/proxy.env? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm "${PROJECT_ROOT}/proxy/proxy.env"
            print_success "proxy/proxy.env removed ✓"
        else
            print_info "Keeping proxy/proxy.env"
        fi
    fi
}

# Main execution
main() {
    cleanup_container
    cleanup_config
    cleanup_proxy_env
    
    echo ""
    print_success "=== Cleanup Complete ==="
    echo ""
    print_info "To set up the test proxy again, run:"
    echo "  ./scripts/setup-test-proxy.sh"
}

# Run main function
main
