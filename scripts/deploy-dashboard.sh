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
DASHBOARD_VERSION="v2.7.0"
DASHBOARD_NAMESPACE="kubernetes-dashboard"
ADMIN_USER="admin-user"
SERVICE_ACCOUNT_NAME="admin-user"

echo -e "${GREEN}=== Kubernetes Dashboard Deployment ===${NC}"
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

# Check if cluster is running
check_cluster() {
    print_info "Checking if cluster is running..."
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cluster is not running or kubectl is not configured"
        exit 1
    fi
    print_info "Cluster is running ✓"
}

# Deploy Kubernetes Dashboard
deploy_dashboard() {
    print_info "Deploying Kubernetes Dashboard ${DASHBOARD_VERSION}..."
    
    # Apply the dashboard manifest
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/${DASHBOARD_VERSION}/aio/deploy/recommended.yaml
    
    print_info "Waiting for dashboard pods to be ready..."
    kubectl wait --for=condition=ready pod -l k8s-app=kubernetes-dashboard -n ${DASHBOARD_NAMESPACE} --timeout=300s
    
    print_success "Dashboard deployed successfully ✓"
}

# Create admin service account
create_admin_user() {
    print_info "Creating admin service account..."
    
    # Create service account
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${SERVICE_ACCOUNT_NAME}
  namespace: ${DASHBOARD_NAMESPACE}
EOF

    print_info "Service account created ✓"
}

# Create cluster role binding
create_cluster_role_binding() {
    print_info "Creating cluster role binding..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${ADMIN_USER}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: ${SERVICE_ACCOUNT_NAME}
  namespace: ${DASHBOARD_NAMESPACE}
EOF

    print_info "Cluster role binding created ✓"
}

# Create long-lived token secret
create_token_secret() {
    print_info "Creating token secret..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${SERVICE_ACCOUNT_NAME}-token
  namespace: ${DASHBOARD_NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${SERVICE_ACCOUNT_NAME}
type: kubernetes.io/service-account-token
EOF

    print_info "Token secret created ✓"
}

# Get access token
get_token() {
    print_info "Retrieving access token..."
    echo ""
    
    # Wait for token to be created
    sleep 2
    
    TOKEN=$(kubectl get secret ${SERVICE_ACCOUNT_NAME}-token -n ${DASHBOARD_NAMESPACE} -o jsonpath='{.data.token}' | base64 --decode)
    
    if [ -z "$TOKEN" ]; then
        print_error "Failed to retrieve token"
        exit 1
    fi
    
    print_success "Access token retrieved ✓"
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Dashboard Access Token:${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo "$TOKEN"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    echo -e "${GREEN}Save this token - you'll need it to log into the dashboard${NC}"
    echo ""
    
    # Save token to file
    echo "$TOKEN" > "${PROJECT_ROOT}/dashboard-token.txt"
    print_info "Token saved to: ${PROJECT_ROOT}/dashboard-token.txt"
}

# Display access instructions
show_access_instructions() {
    echo ""
    print_success "=== Dashboard Deployment Complete ==="
    echo ""
    print_info "To access the dashboard:"
    echo ""
    echo -e "${GREEN}1. Start the proxy:${NC}"
    echo "   make dashboard-proxy"
    echo "   or: kubectl proxy"
    echo ""
    echo -e "${GREEN}2. Open in browser:${NC}"
    echo "   http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
    echo ""
    echo -e "${GREEN}3. Login using the token from:${NC}"
    echo "   cat dashboard-token.txt"
    echo "   or: make dashboard-token"
    echo ""
    print_warning "Note: Keep the proxy running while accessing the dashboard"
}

# Main execution
main() {
    check_cluster
    deploy_dashboard
    create_admin_user
    create_cluster_role_binding
    create_token_secret
    get_token
    show_access_instructions
}

# Run main function
main
