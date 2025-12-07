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
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROXY_CONTAINER_NAME="test-corporate-proxy"
PROXY_PORT="3128"
PROXY_AUTH_PORT="3129"
SQUID_CONFIG_DIR="${PROJECT_ROOT}/test-proxy"

echo -e "${GREEN}=== Test Corporate Proxy Setup ===${NC}"
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

print_success() {
    echo -e "${BLUE}[SUCCESS]${NC} $1"
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

# Stop existing proxy container
stop_existing_proxy() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${PROXY_CONTAINER_NAME}$"; then
        print_info "Stopping existing proxy container..."
        docker stop ${PROXY_CONTAINER_NAME} 2>/dev/null || true
        docker rm ${PROXY_CONTAINER_NAME} 2>/dev/null || true
        print_info "Existing proxy removed ✓"
    fi
}

# Create Squid configuration directory
create_config_dir() {
    print_info "Creating Squid configuration directory..."
    mkdir -p "${SQUID_CONFIG_DIR}"
    
    # Create basic Squid configuration (no auth)
    cat > "${SQUID_CONFIG_DIR}/squid.conf" <<'EOF'
# Squid configuration for testing Kind proxy support
# This simulates a corporate proxy without authentication

# HTTP port
http_port 3128

# Access control
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 172.18.0.0/16
acl localnet src 192.168.0.0/16
acl localnet src fc00::/7
acl localnet src fe80::/10

acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
acl Safe_ports port 1025-65535
acl CONNECT method CONNECT

# Deny requests to certain unsafe ports
http_access deny !Safe_ports

# Deny CONNECT to other than secure SSL ports
http_access deny CONNECT !SSL_ports

# Allow localhost
http_access allow localhost manager
http_access deny manager

# Allow local networks (including Docker networks)
http_access allow localnet
http_access allow localhost

# Allow all for testing (INSECURE - for local testing only!)
http_access allow all

# Cache settings (minimal for testing)
cache_dir ufs /var/spool/squid 100 16 256
coredump_dir /var/spool/squid

# Logging
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log

# Refresh patterns
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320

# Visible hostname
visible_hostname test-proxy
EOF

    # Create authenticated Squid configuration
    cat > "${SQUID_CONFIG_DIR}/squid-auth.conf" <<'EOF'
# Squid configuration with basic authentication
# This simulates a corporate proxy WITH authentication

# HTTP port
http_port 3129

# Authentication
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwords
auth_param basic children 5
auth_param basic realm Corporate Proxy
auth_param basic credentialsttl 2 hours

acl authenticated proxy_auth REQUIRED

# Access control
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 172.18.0.0/16
acl localnet src 192.168.0.0/16
acl localnet src fc00::/7
acl localnet src fe80::/10

acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
acl Safe_ports port 1025-65535
acl CONNECT method CONNECT

# Deny requests to certain unsafe ports
http_access deny !Safe_ports

# Deny CONNECT to other than secure SSL ports
http_access deny CONNECT !SSL_ports

# Allow localhost without auth
http_access allow localhost manager
http_access deny manager

# Require authentication for all other access
http_access allow authenticated
http_access allow localhost

# Allow all for testing (INSECURE - for local testing only!)
http_access allow all

# Cache settings (minimal for testing)
cache_dir ufs /var/spool/squid 100 16 256
coredump_dir /var/spool/squid

# Logging
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log

# Refresh patterns
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320

# Visible hostname
visible_hostname test-proxy-auth
EOF

    print_info "Squid configuration created ✓"
}

# Start Squid proxy container
start_proxy() {
    local AUTH_MODE=$1
    
    if [ "$AUTH_MODE" = "auth" ]; then
        print_info "Starting Squid proxy with authentication on port ${PROXY_AUTH_PORT}..."
        
        # Create password file (user: testuser, password: testpass)
        mkdir -p "${SQUID_CONFIG_DIR}/auth"
        docker run --rm ubuntu/squid:latest htpasswd -bc /tmp/passwords testuser testpass > "${SQUID_CONFIG_DIR}/auth/passwords" 2>/dev/null || \
            echo "testuser:$(openssl passwd -apr1 testpass)" > "${SQUID_CONFIG_DIR}/auth/passwords"
        
        docker run -d \
            --name ${PROXY_CONTAINER_NAME} \
            -p ${PROXY_AUTH_PORT}:3129 \
            -v "${SQUID_CONFIG_DIR}/squid-auth.conf:/etc/squid/squid.conf:ro" \
            -v "${SQUID_CONFIG_DIR}/auth/passwords:/etc/squid/passwords:ro" \
            ubuntu/squid:latest
        
        print_success "Squid proxy with auth started on port ${PROXY_AUTH_PORT} ✓"
        echo ""
        echo -e "${YELLOW}Authentication credentials:${NC}"
        echo "  Username: testuser"
        echo "  Password: testpass"
    else
        print_info "Starting Squid proxy (no auth) on port ${PROXY_PORT}..."
        
        docker run -d \
            --name ${PROXY_CONTAINER_NAME} \
            -p ${PROXY_PORT}:3128 \
            -v "${SQUID_CONFIG_DIR}/squid.conf:/etc/squid/squid.conf:ro" \
            ubuntu/squid:latest
        
        print_success "Squid proxy (no auth) started on port ${PROXY_PORT} ✓"
    fi
}

# Wait for proxy to be ready
wait_for_proxy() {
    local PORT=$1
    print_info "Waiting for proxy to be ready..."
    
    for i in {1..30}; do
        if curl -s -o /dev/null -x "http://localhost:${PORT}" http://www.google.com 2>/dev/null; then
            print_success "Proxy is ready ✓"
            return 0
        fi
        sleep 1
    done
    
    print_warning "Proxy may not be fully ready yet, but continuing..."
}

# Test proxy connectivity
test_proxy() {
    local PORT=$1
    local AUTH=$2
    
    print_info "Testing proxy connectivity..."
    
    if [ -n "$AUTH" ]; then
        # Test with authentication
        if curl -s -o /dev/null -x "http://testuser:testpass@localhost:${PORT}" http://www.google.com; then
            print_success "Proxy with auth is working ✓"
        else
            print_error "Proxy with auth test failed"
            return 1
        fi
    else
        # Test without authentication
        if curl -s -o /dev/null -x "http://localhost:${PORT}" http://www.google.com; then
            print_success "Proxy (no auth) is working ✓"
        else
            print_error "Proxy test failed"
            return 1
        fi
    fi
}

# Create proxy.env for testing
create_test_proxy_env() {
    local PORT=$1
    local AUTH=$2
    
    print_info "Creating test proxy configuration..."
    
    if [ -n "$AUTH" ]; then
        cat > "${PROJECT_ROOT}/proxy/proxy.env" <<EOF
# Test Corporate Proxy Configuration (WITH AUTHENTICATION)
# Generated by setup-test-proxy.sh
# Note: Using host.docker.internal to reach host from Kind containers

HTTP_PROXY=http://testuser:testpass@host.docker.internal:${PORT}
http_proxy=http://testuser:testpass@host.docker.internal:${PORT}
HTTPS_PROXY=http://testuser:testpass@host.docker.internal:${PORT}
https_proxy=http://testuser:testpass@host.docker.internal:${PORT}

NO_PROXY=localhost,127.0.0.1,127.0.0.*,172.17.*,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16
no_proxy=localhost,127.0.0.1,127.0.0.*,172.17.*,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16

# Test credentials
PROXY_USER=testuser
PROXY_PASS=testpass
EOF
    else
        cat > "${PROJECT_ROOT}/proxy/proxy.env" <<EOF
# Test Corporate Proxy Configuration (NO AUTHENTICATION)
# Generated by setup-test-proxy.sh
# Note: Using host.docker.internal to reach host from Kind containers

HTTP_PROXY=http://host.docker.internal:${PORT}
http_proxy=http://host.docker.internal:${PORT}
HTTPS_PROXY=http://host.docker.internal:${PORT}
https_proxy=http://host.docker.internal:${PORT}

NO_PROXY=localhost,127.0.0.1,127.0.0.*,172.17.*,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16
no_proxy=localhost,127.0.0.1,127.0.0.*,172.17.*,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16
EOF
    fi
    
    print_success "Test proxy configuration created at proxy/proxy.env ✓"
}

# Show usage instructions
show_instructions() {
    local PORT=$1
    local AUTH=$2
    
    echo ""
    echo -e "${GREEN}=== Test Proxy Setup Complete ===${NC}"
    echo ""
    echo -e "${YELLOW}Proxy Details:${NC}"
    if [ -n "$AUTH" ]; then
        echo "  URL: http://localhost:${PORT}"
        echo "  Authentication: YES"
        echo "  Username: testuser"
        echo "  Password: testpass"
    else
        echo "  URL: http://localhost:${PORT}"
        echo "  Authentication: NO"
    fi
    echo ""
    echo -e "${YELLOW}Test the proxy:${NC}"
    if [ -n "$AUTH" ]; then
        echo "  curl -x http://testuser:testpass@localhost:${PORT} http://www.google.com"
    else
        echo "  curl -x http://localhost:${PORT} http://www.google.com"
    fi
    echo ""
    echo -e "${YELLOW}View proxy logs:${NC}"
    echo "  docker logs -f ${PROXY_CONTAINER_NAME}"
    echo ""
    echo -e "${YELLOW}Create Kind cluster with test proxy:${NC}"
    echo "  make create-cluster"
    echo ""
    echo -e "${YELLOW}Stop test proxy:${NC}"
    echo "  docker stop ${PROXY_CONTAINER_NAME}"
    echo "  docker rm ${PROXY_CONTAINER_NAME}"
    echo ""
    echo -e "${YELLOW}Or use the cleanup script:${NC}"
    echo "  ./scripts/cleanup-test-proxy.sh"
    echo ""
}

# Main execution
main() {
    local AUTH_MODE=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auth)
                AUTH_MODE="auth"
                shift
                ;;
            --no-auth)
                AUTH_MODE=""
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [--auth|--no-auth]"
                echo ""
                echo "Options:"
                echo "  --auth      Start proxy with authentication (port 3129)"
                echo "  --no-auth   Start proxy without authentication (port 3128, default)"
                echo "  -h, --help  Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    check_docker
    stop_existing_proxy
    create_config_dir
    
    if [ "$AUTH_MODE" = "auth" ]; then
        start_proxy "auth"
        wait_for_proxy ${PROXY_AUTH_PORT}
        test_proxy ${PROXY_AUTH_PORT} "auth"
        create_test_proxy_env ${PROXY_AUTH_PORT} "auth"
        show_instructions ${PROXY_AUTH_PORT} "auth"
    else
        start_proxy
        wait_for_proxy ${PROXY_PORT}
        test_proxy ${PROXY_PORT}
        create_test_proxy_env ${PROXY_PORT}
        show_instructions ${PROXY_PORT}
    fi
}

# Run main function
main "$@"
