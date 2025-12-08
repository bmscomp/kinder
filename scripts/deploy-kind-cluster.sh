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
CLUSTER_NAME="celine"
CONFIG_FILE="config/kind-cluster-config.yaml"
PROXY_CONFIG_FILE="proxy/proxy.env"
PROXY_EXAMPLE_FILE="proxy/proxy.env.example"

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
        
        # Handle proxy authentication if provided
        if [ -n "$PROXY_USER" ] && [ -n "$PROXY_PASS" ]; then
            print_info "Proxy authentication detected, constructing authenticated URLs..."
            PROXY_AUTH="${PROXY_USER}:${PROXY_PASS}@"
            
            # Reconstruct proxy URLs with authentication
            if [ -n "$HTTP_PROXY" ]; then
                HTTP_PROXY=$(echo "$HTTP_PROXY" | sed "s|://|://${PROXY_AUTH}|")
            fi
            if [ -n "$HTTPS_PROXY" ]; then
                HTTPS_PROXY=$(echo "$HTTPS_PROXY" | sed "s|://|://${PROXY_AUTH}|")
            fi
        fi
        
        if [ -n "$HTTP_PROXY" ]; then
            export HTTP_PROXY
            export http_proxy="$HTTP_PROXY"
            # Mask password in output
            DISPLAY_PROXY=$(echo "$HTTP_PROXY" | sed 's|://[^:]*:[^@]*@|://***:***@|')
            print_info "HTTP_PROXY: $DISPLAY_PROXY"
        fi
        
        if [ -n "$HTTPS_PROXY" ]; then
            export HTTPS_PROXY
            export https_proxy="$HTTPS_PROXY"
            DISPLAY_PROXY=$(echo "$HTTPS_PROXY" | sed 's|://[^:]*:[^@]*@|://***:***@|')
            print_info "HTTPS_PROXY: $DISPLAY_PROXY"
        fi
        
        if [ -n "$NO_PROXY" ]; then
            export NO_PROXY
            export no_proxy="$NO_PROXY"
            print_info "NO_PROXY: $NO_PROXY"
        fi
    else
        print_warning "No proxy configuration file found at $PROXY_CONFIG_FILE"
        print_info "To use a proxy, copy and configure the example file:"
        echo "  cp $PROXY_EXAMPLE_FILE $PROXY_CONFIG_FILE"
        echo "  Then edit $PROXY_CONFIG_FILE with your proxy settings"
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
    
    # Create cluster
    kind create cluster --config "$CONFIG_FILE" --name "$CLUSTER_NAME"
    
    if [ $? -eq 0 ]; then
        print_info "Cluster created successfully ✓"
    else
        print_error "Failed to create cluster"
        exit 1
    fi
}

# Configure DNS from host to nodes
configure_dns() {
    print_info "Configuring DNS from host machine..."
    
    # Get DNS servers from host
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - use scutil to get DNS servers
        DNS_SERVERS=$(scutil --dns | grep 'nameserver\[' | awk '{print $3}' | sort -u)
    else
        # Linux - read from /etc/resolv.conf
        DNS_SERVERS=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}')
    fi
    
    if [ -z "$DNS_SERVERS" ]; then
        print_warning "No DNS servers found on host, skipping DNS configuration"
        return
    fi
    
    print_info "Host DNS servers: $(echo $DNS_SERVERS | tr '\n' ' ')"
    
    # Get all node names
    NODES=$(kind get nodes --name "$CLUSTER_NAME")
    
    for NODE in $NODES; do
        print_info "Configuring DNS for $NODE..."
        
        # Backup original resolv.conf
        docker exec "$NODE" bash -c "cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true"
        
        # Create new resolv.conf with host DNS servers
        docker exec "$NODE" bash -c "cat > /etc/resolv.conf << 'EOF'
# DNS configuration from host machine
# Generated by deploy-kind-cluster.sh
EOF"
        
        # Add each DNS server
        for DNS in $DNS_SERVERS; do
            docker exec "$NODE" bash -c "echo 'nameserver $DNS' >> /etc/resolv.conf"
        done
        
        # Add search domains and options
        docker exec "$NODE" bash -c "cat >> /etc/resolv.conf << 'EOF'
search cluster.local svc.cluster.local
options ndots:5
EOF"
        
        print_info "DNS configured for $NODE ✓"
        
        # Show the configuration
        print_info "DNS configuration for $NODE:"
        docker exec "$NODE" cat /etc/resolv.conf | grep -E "^nameserver|^search|^options" || true
    done
    
    print_info "DNS configuration completed ✓"
}

# Install useful utilities on all nodes
install_utilities() {
    print_info "Installing utilities on all nodes..."
    
    # Get all node names
    NODES=$(kind get nodes --name "$CLUSTER_NAME")
    
    for NODE in $NODES; do
        print_info "Installing utilities on $NODE..."
        
        # Update package lists
        docker exec "$NODE" bash -c "apt-get update -qq 2>/dev/null" || true
        
        # Install utilities
        # - dnsutils: provides nslookup, dig, host
        # - vim: text editor
        # - iputils-ping: provides ping
        # - coreutils: provides cat (usually already installed)
        docker exec "$NODE" bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq dnsutils vim iputils-ping coreutils 2>/dev/null" || true
        
        print_info "Utilities installed on $NODE ✓"
    done
    
    print_info "Utility installation completed ✓"
    print_info "Available tools: nslookup, dig, vim, ping, cat"
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
            
            # Configure kubelet proxy
            docker exec "$NODE" bash -c "mkdir -p /etc/systemd/system/kubelet.service.d"
            docker exec "$NODE" bash -c "echo -e '$PROXY_CONF' > /etc/systemd/system/kubelet.service.d/http-proxy.conf"
            
            # Set environment variables in the node
            docker exec "$NODE" bash -c "cat >> /etc/environment << EOF
HTTP_PROXY=$HTTP_PROXY
HTTPS_PROXY=$HTTPS_PROXY
NO_PROXY=$NO_PROXY
http_proxy=$HTTP_PROXY
https_proxy=$HTTPS_PROXY
no_proxy=$NO_PROXY
EOF"
            
            # Reload and restart services
            docker exec "$NODE" systemctl daemon-reload 2>/dev/null || true
            docker exec "$NODE" systemctl restart containerd 2>/dev/null || true
            
            print_info "Proxy configured for $NODE ✓"
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
    configure_dns
    install_utilities
    configure_nodes
    label_nodes
    verify_cluster
    
    echo ""
    print_info "${GREEN}=== Cluster deployment completed successfully! ===${NC}"
    echo ""
    print_info "Cluster name: $CLUSTER_NAME"
    print_info "Nodes: paris (control-plane), berlin (worker), london (worker)"
    print_info "Resources per node: ${NODE_CPUS} CPUs, ${NODE_MEMORY} memory"
    print_info "Installed utilities: nslookup, dig, vim, ping, cat"
    echo ""
    print_info "To interact with your cluster:"
    echo "  kubectl get nodes"
    echo "  kubectl get pods -A"
    echo ""
    print_info "Shell into nodes:"
    echo "  make shell-paris   # Control plane"
    echo "  make shell-berlin  # Worker 1"
    echo "  make shell-london  # Worker 2"
    echo ""
    print_info "To delete the cluster:"
    echo "  make delete-cluster"
    echo "  or: kind delete cluster --name $CLUSTER_NAME"
}

# Run main function
main
