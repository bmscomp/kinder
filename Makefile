.PHONY: help create-cluster delete-cluster status get-nodes get-pods shell-paris shell-berlin shell-london configure-proxy clean

# Default cluster name
CLUSTER_NAME := corporate-cluster

# Color output
GREEN  := \033[0;32m
YELLOW := \033[1;33m
NC     := \033[0m # No Color

help: ## Show this help message
	@echo "$(GREEN)Kind Kubernetes Cluster Management$(NC)"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Cluster configuration:"
	@echo "  - Name: $(CLUSTER_NAME)"
	@echo "  - Nodes: paris (control-plane), berlin (worker), london (worker)"
	@echo "  - Resources: 4 CPUs, 10GB memory per node"

create-cluster: ## Create and deploy the Kind cluster
	@echo "$(GREEN)Creating Kind cluster...$(NC)"
	@./scripts/deploy-kind-cluster.sh

delete-cluster: ## Delete the Kind cluster
	@echo "$(YELLOW)Deleting Kind cluster: $(CLUSTER_NAME)$(NC)"
	@kind delete cluster --name $(CLUSTER_NAME) || echo "Cluster does not exist"
	@echo "$(GREEN)Cluster deleted successfully$(NC)"

status: ## Show cluster status
	@echo "$(GREEN)Cluster Status:$(NC)"
	@kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$" && echo "Cluster $(CLUSTER_NAME) exists ✓" || echo "Cluster $(CLUSTER_NAME) does not exist ✗"
	@echo ""
	@if kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		echo "$(GREEN)Nodes:$(NC)"; \
		kubectl get nodes -o wide; \
		echo ""; \
		echo "$(GREEN)Cluster Info:$(NC)"; \
		kubectl cluster-info; \
	fi

get-nodes: ## List all nodes with labels
	@echo "$(GREEN)Cluster Nodes:$(NC)"
	@kubectl get nodes --show-labels

get-pods: ## List all pods in all namespaces
	@echo "$(GREEN)All Pods:$(NC)"
	@kubectl get pods -A -o wide

get-services: ## List all services in all namespaces
	@echo "$(GREEN)All Services:$(NC)"
	@kubectl get services -A

shell-paris: ## Open shell in paris node (control-plane)
	@echo "$(GREEN)Opening shell in paris node...$(NC)"
	@docker exec -it $(CLUSTER_NAME)-control-plane bash

shell-berlin: ## Open shell in berlin node (worker)
	@echo "$(GREEN)Opening shell in berlin node...$(NC)"
	@docker exec -it $(CLUSTER_NAME)-worker bash

shell-london: ## Open shell in london node (worker)
	@echo "$(GREEN)Opening shell in london node...$(NC)"
	@docker exec -it $(CLUSTER_NAME)-worker2 bash

configure-proxy: ## Create proxy configuration file from template
	@if [ ! -f proxy/proxy.env ]; then \
		echo "$(GREEN)Creating proxy configuration from template...$(NC)"; \
		cp proxy/proxy.env.example proxy/proxy.env; \
		echo "$(GREEN)Proxy configuration created at proxy/proxy.env$(NC)"; \
		echo "$(YELLOW)Please edit proxy/proxy.env with your proxy settings before creating the cluster$(NC)"; \
		echo ""; \
		echo "Example configuration:"; \
		echo "  HTTP_PROXY=http://proxy.company.com:8080"; \
		echo "  HTTPS_PROXY=http://proxy.company.com:8080"; \
		echo "  NO_PROXY=localhost,127.0.0.1,.local,.svc,.cluster.local"; \
	else \
		echo "$(YELLOW)proxy/proxy.env already exists$(NC)"; \
		echo "Current configuration:"; \
		grep -v "^#" proxy/proxy.env | grep -v "^$$" || echo "  (empty or all commented)"; \
	fi

show-proxy: ## Show current proxy configuration
	@if [ -f proxy/proxy.env ]; then \
		echo "$(GREEN)Current proxy configuration:$(NC)"; \
		cat proxy/proxy.env; \
	else \
		echo "$(YELLOW)No proxy configuration found at proxy/proxy.env$(NC)"; \
		echo "Run 'make configure-proxy' to create one"; \
	fi

logs-paris: ## Show logs from paris node
	@echo "$(GREEN)Logs from paris node:$(NC)"
	@docker logs $(CLUSTER_NAME)-control-plane

logs-berlin: ## Show logs from berlin node
	@echo "$(GREEN)Logs from berlin node:$(NC)"
	@docker logs $(CLUSTER_NAME)-worker

logs-london: ## Show logs from london node
	@echo "$(GREEN)Logs from london node:$(NC)"
	@docker logs $(CLUSTER_NAME)-worker2

restart-cluster: delete-cluster create-cluster ## Delete and recreate the cluster

inspect-paris: ## Inspect paris node container
	@docker inspect $(CLUSTER_NAME)-control-plane

inspect-berlin: ## Inspect berlin node container
	@docker inspect $(CLUSTER_NAME)-worker

inspect-london: ## Inspect london node container
	@docker inspect $(CLUSTER_NAME)-worker2

load-image: ## Load a Docker image into the cluster (usage: make load-image IMAGE=myimage:tag)
	@if [ -z "$(IMAGE)" ]; then \
		echo "$(YELLOW)Usage: make load-image IMAGE=myimage:tag$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Loading image $(IMAGE) into cluster...$(NC)"
	@kind load docker-image $(IMAGE) --name $(CLUSTER_NAME)

export-logs: ## Export cluster logs to a directory
	@echo "$(GREEN)Exporting cluster logs...$(NC)"
	@kind export logs --name $(CLUSTER_NAME) ./cluster-logs
	@echo "$(GREEN)Logs exported to ./cluster-logs$(NC)"

clean: delete-cluster ## Clean up cluster and generated files
	@echo "$(GREEN)Cleaning up...$(NC)"
	@rm -rf ./cluster-logs
	@echo "$(GREEN)Cleanup complete$(NC)"

install-deps: ## Install required dependencies (kind, kubectl)
	@echo "$(GREEN)Installing dependencies...$(NC)"
	@if ! command -v kind &> /dev/null; then \
		echo "Installing kind..."; \
		brew install kind; \
	else \
		echo "kind already installed ✓"; \
	fi
	@if ! command -v kubectl &> /dev/null; then \
		echo "Installing kubectl..."; \
		brew install kubectl; \
	else \
		echo "kubectl already installed ✓"; \
	fi
	@echo "$(GREEN)Dependencies installed$(NC)"

check-deps: ## Check if required dependencies are installed
	@echo "$(GREEN)Checking dependencies...$(NC)"
	@command -v docker &> /dev/null && echo "✓ Docker installed" || echo "✗ Docker not installed"
	@command -v kind &> /dev/null && echo "✓ kind installed" || echo "✗ kind not installed"
	@command -v kubectl &> /dev/null && echo "✓ kubectl installed" || echo "✗ kubectl not installed"
	@docker info &> /dev/null && echo "✓ Docker daemon running" || echo "✗ Docker daemon not running"
