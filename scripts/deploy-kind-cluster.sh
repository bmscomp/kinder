#!/bin/bash

set -e

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to project root
cd "$PROJECT_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="corporate-cluster"
CONFIG_FILE="config/kind-cluster-config.yaml"
PROXY_CONFIG_FILE=".proxy-config"

# Node resource configuration
NODE_MEMORY="10240m"  # 10GB
NODE_CPUS="4"

echo -e "${GREEN}=== Kind Cluster Deployment Script ===${NC}"
echo ""

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
check_docker() {
    print_info "Checking if Docker is running..."
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker Desktop and try again."
        exit 1
    fi
    print_info "Docker is running ✓"
}

# Check if kind is installed
check_kind() {
    print_info "Checking if kind is installed..."
    if ! command -v kind &> /dev/null; then
        print_error "kind is not installed. Installing via Homebrew..."
        brew install kind
    fi
    print_info "kind is installed ✓"
}

# Load proxy configuration
load_proxy_config() {
    if [ -f "$PROXY_CONFIG_FILE" ]; then
        print_info "Loading proxy configuration from $PROXY_CONFIG_FILE"
        source "$PROXY_CONFIG_FILE"
        
        if [ -n "$HTTP_PROXY" ]; then
            export HTTP_PROXY
            export http_proxy="$HTTP_PROXY"
            print_info "HTTP_PROXY: $HTTP_PROXY"
        fi
        
        if [ -n "$HTTPS_PROXY" ]; then
            export HTTPS_PROXY
            export https_proxy="$HTTPS_PROXY"
            print_info "HTTPS_PROXY: $HTTPS_PROXY"
        fi
        
        if [ -n "$NO_PROXY" ]; then
            export NO_PROXY
            export no_proxy="$NO_PROXY"
            print_info "NO_PROXY: $NO_PROXY"
        fi
    else
        print_warning "No proxy configuration file found at $PROXY_CONFIG_FILE"
        print_info "To use a proxy, create $PROXY_CONFIG_FILE with the following content:"
        echo "  HTTP_PROXY=http://proxy.company.com:8080"
        echo "  HTTPS_PROXY=http://proxy.company.com:8080"
        echo "  NO_PROXY=localhost,127.0.0.1,.local,.svc,.cluster.local"
    fi
}

# Configure Docker daemon for proxy
configure_docker_proxy() {
    if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
        print_info "Configuring Docker daemon with proxy settings..."
        
        # Create Docker daemon config directory if it doesn't exist
        DOCKER_CONFIG_DIR="$HOME/.docker"
        mkdir -p "$DOCKER_CONFIG_DIR"
        
        # Note: On macOS with Docker Desktop, proxy settings should be configured
        # through Docker Desktop UI: Settings > Resources > Proxies
        print_warning "For Docker Desktop on macOS, ensure proxy settings are configured in:"
        print_warning "Docker Desktop > Settings > Resources > Proxies"
    fi
}

# Create kind cluster with resource limits
create_cluster() {
    print_info "Creating Kind cluster: $CLUSTER_NAME"
    print_info "Node configuration: ${NODE_CPUS} CPUs, ${NODE_MEMORY} memory per node"
    
    # Check if cluster already exists
    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        print_warning "Cluster $CLUSTER_NAME already exists!"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Deleting existing cluster..."
            kind delete cluster --name "$CLUSTER_NAME"
        else
            print_info "Keeping existing cluster. Exiting."
            exit 0
        fi
    fi
    
    # Create the cluster
    print_info "Creating cluster with configuration from $CONFIG_FILE..."
    
    # Set Docker resource limits via environment variables
    export KIND_EXPERIMENTAL_DOCKER_NETWORK="bridge"
    
    # Create cluster
    kind create cluster --config "$CONFIG_FILE" --name "$CLUSTER_NAME"
    
    if [ $? -eq 0 ]; then
        print_info "Cluster created successfully ✓"
    else
        print_error "Failed to create cluster"
        exit 1
    fi
}

# Configure nodes with resource limits and proxy
configure_nodes() {
    print_info "Configuring cluster nodes..."
    
    # Get all node names
    NODES=$(kind get nodes --name "$CLUSTER_NAME")
    
    for NODE in $NODES; do
        print_info "Configuring node: $NODE"
        
        # Set resource limits (Docker container limits)
        docker update --memory="$NODE_MEMORY" --cpus="$NODE_CPUS" "$NODE" 2>/dev/null || true
        
        # Configure proxy settings inside the node if proxy is set
        if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
            print_info "Configuring proxy settings for $NODE..."
            
            # Configure containerd proxy
            docker exec "$NODE" bash -c "mkdir -p /etc/systemd/system/containerd.service.d"
            
            PROXY_CONF="[Service]\n"
            [ -n "$HTTP_PROXY" ] && PROXY_CONF+="Environment=\"HTTP_PROXY=$HTTP_PROXY\"\n"
            [ -n "$HTTPS_PROXY" ] && PROXY_CONF+="Environment=\"HTTPS_PROXY=$HTTPS_PROXY\"\n"
            [ -n "$NO_PROXY" ] && PROXY_CONF+="Environment=\"NO_PROXY=$NO_PROXY\"\n"
            
            docker exec "$NODE" bash -c "echo -e '$PROXY_CONF' > /etc/systemd/system/containerd.service.d/http-proxy.conf"
            docker exec "$NODE" systemctl daemon-reload 2>/dev/null || true
            docker exec "$NODE" systemctl restart containerd 2>/dev/null || true
        fi
    done
    
    print_info "Node configuration completed ✓"
}

# Verify cluster
verify_cluster() {
    print_info "Verifying cluster..."
    
    # Wait for nodes to be ready
    print_info "Waiting for nodes to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    print_info "Cluster nodes:"
    kubectl get nodes -o wide
    
    print_info ""
    print_info "Cluster info:"
    kubectl cluster-info
    
    print_info ""
    print_info "Node labels:"
    kubectl get nodes --show-labels
}

# Label nodes with custom names
label_nodes() {
    print_info "Applying custom node labels..."
    
    # Get nodes and apply labels
    CONTROL_PLANE=$(kubectl get nodes -o name | grep control-plane | head -n 1)
    WORKERS=($(kubectl get nodes -o name | grep -v control-plane))
    
    if [ -n "$CONTROL_PLANE" ]; then
        kubectl label "$CONTROL_PLANE" city=paris --overwrite
        print_info "Labeled $CONTROL_PLANE as paris"
    fi
    
    if [ ${#WORKERS[@]} -ge 1 ]; then
        kubectl label "${WORKERS[0]}" city=berlin --overwrite
        print_info "Labeled ${WORKERS[0]} as berlin"
    fi
    
    if [ ${#WORKERS[@]} -ge 2 ]; then
        kubectl label "${WORKERS[1]}" city=london --overwrite
        print_info "Labeled ${WORKERS[1]} as london"
    fi
}

# Main execution
main() {
    check_docker
    check_kind
    load_proxy_config
    configure_docker_proxy
    create_cluster
    configure_nodes
    label_nodes
    verify_cluster
    
    echo ""
    print_info "${GREEN}=== Cluster deployment completed successfully! ===${NC}"
    echo ""
    print_info "Cluster name: $CLUSTER_NAME"
    print_info "Nodes: paris (control-plane), berlin (worker), london (worker)"
    print_info "Resources per node: ${NODE_CPUS} CPUs, ${NODE_MEMORY} memory"
    echo ""
    print_info "To interact with your cluster:"
    echo "  kubectl get nodes"
    echo "  kubectl get pods -A"
    echo ""
    print_info "To delete the cluster:"
    echo "  make delete-cluster"
    echo "  or: kind delete cluster --name $CLUSTER_NAME"
}

# Run main function
main
