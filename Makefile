.PHONY: help create-cluster delete-cluster status get-nodes get-pods shell-paris shell-berlin shell-london configure-proxy clean configure-containerd-proxy check-containerd-proxy restart-containerd deploy-dashboard delete-dashboard dashboard-proxy dashboard-token dashboard-url test-proxy test-proxy-auth cleanup-test-proxy set-context

# Default cluster name
CLUSTER_NAME := celine

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

set-context: ## Set kubectl context to the Kind cluster
	@echo "$(GREEN)Setting kubectl context to $(CLUSTER_NAME)...$(NC)"
	@if kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		kubectl config use-context kind-$(CLUSTER_NAME); \
		echo "$(GREEN)Context set to kind-$(CLUSTER_NAME) ✓$(NC)"; \
		echo ""; \
		echo "$(GREEN)Current context:$(NC)"; \
		kubectl config current-context; \
	else \
		echo "$(YELLOW)Cluster $(CLUSTER_NAME) does not exist.$(NC)"; \
		echo "Create it first with: make create-cluster"; \
		exit 1; \
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

configure-containerd-proxy: ## Configure containerd with proxy settings on all nodes
	@if [ ! -f proxy/proxy.env ]; then \
		echo "$(YELLOW)No proxy configuration found at proxy/proxy.env$(NC)"; \
		echo "Run 'make configure-proxy' first to create proxy configuration"; \
		exit 1; \
	fi
	@echo "$(GREEN)Configuring containerd proxy on all cluster nodes...$(NC)"
	@. proxy/proxy.env; \
	if [ -n "$$PROXY_USER" ] && [ -n "$$PROXY_PASS" ]; then \
		PROXY_AUTH="$$PROXY_USER:$$PROXY_PASS@"; \
		HTTP_PROXY=$$(echo "$$HTTP_PROXY" | sed "s|://|://$$PROXY_AUTH|"); \
		HTTPS_PROXY=$$(echo "$$HTTPS_PROXY" | sed "s|://|://$$PROXY_AUTH|"); \
	fi; \
	PROXY_CONF="[Service]\n"; \
	[ -n "$$HTTP_PROXY" ] && PROXY_CONF+="Environment=\"HTTP_PROXY=$$HTTP_PROXY\"\n"; \
	[ -n "$$HTTPS_PROXY" ] && PROXY_CONF+="Environment=\"HTTPS_PROXY=$$HTTPS_PROXY\"\n"; \
	[ -n "$$NO_PROXY" ] && PROXY_CONF+="Environment=\"NO_PROXY=$$NO_PROXY\"\n"; \
	for NODE in $(CLUSTER_NAME)-control-plane $(CLUSTER_NAME)-worker $(CLUSTER_NAME)-worker2; do \
		echo "$(GREEN)Configuring $$NODE...$(NC)"; \
		docker exec $$NODE bash -c "mkdir -p /etc/systemd/system/containerd.service.d"; \
		docker exec $$NODE bash -c "echo -e '$$PROXY_CONF' > /etc/systemd/system/containerd.service.d/http-proxy.conf"; \
		docker exec $$NODE bash -c "mkdir -p /etc/systemd/system/kubelet.service.d"; \
		docker exec $$NODE bash -c "echo -e '$$PROXY_CONF' > /etc/systemd/system/kubelet.service.d/http-proxy.conf"; \
		docker exec $$NODE bash -c "cat >> /etc/environment << EOF\nHTTP_PROXY=$$HTTP_PROXY\nHTTPS_PROXY=$$HTTPS_PROXY\nNO_PROXY=$$NO_PROXY\nhttp_proxy=$$HTTP_PROXY\nhttps_proxy=$$HTTPS_PROXY\nno_proxy=$$NO_PROXY\nEOF" 2>/dev/null || true; \
		docker exec $$NODE systemctl daemon-reload 2>/dev/null || true; \
		docker exec $$NODE systemctl restart containerd 2>/dev/null || true; \
		echo "$(GREEN)✓ $$NODE configured$(NC)"; \
	done
	@echo "$(GREEN)Containerd proxy configuration completed for all nodes$(NC)"

check-containerd-proxy: ## Check containerd proxy configuration on all nodes
	@echo "$(GREEN)Checking containerd proxy configuration on all nodes...$(NC)"
	@echo ""
	@for NODE in $(CLUSTER_NAME)-control-plane $(CLUSTER_NAME)-worker $(CLUSTER_NAME)-worker2; do \
		echo "$(GREEN)=== $$NODE ===$(NC)"; \
		echo "$(YELLOW)Containerd proxy config:$(NC)"; \
		docker exec $$NODE cat /etc/systemd/system/containerd.service.d/http-proxy.conf 2>/dev/null || echo "  No proxy config found"; \
		echo ""; \
		echo "$(YELLOW)Kubelet proxy config:$(NC)"; \
		docker exec $$NODE cat /etc/systemd/system/kubelet.service.d/http-proxy.conf 2>/dev/null || echo "  No proxy config found"; \
		echo ""; \
		echo "$(YELLOW)Environment variables:$(NC)"; \
		docker exec $$NODE bash -c "grep -E '(HTTP_PROXY|HTTPS_PROXY|NO_PROXY)' /etc/environment 2>/dev/null" || echo "  No proxy environment variables found"; \
		echo ""; \
		echo "---"; \
		echo ""; \
	done

restart-containerd: ## Restart containerd service on all nodes
	@echo "$(GREEN)Restarting containerd on all cluster nodes...$(NC)"
	@for NODE in $(CLUSTER_NAME)-control-plane $(CLUSTER_NAME)-worker $(CLUSTER_NAME)-worker2; do \
		echo "$(GREEN)Restarting containerd on $$NODE...$(NC)"; \
		docker exec $$NODE systemctl daemon-reload 2>/dev/null || true; \
		docker exec $$NODE systemctl restart containerd 2>/dev/null || true; \
		echo "$(GREEN)✓ $$NODE containerd restarted$(NC)"; \
	done
	@echo "$(GREEN)Containerd restart completed for all nodes$(NC)"

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

deploy-dashboard: ## Deploy Kubernetes Dashboard to the cluster
	@echo "$(GREEN)Deploying Kubernetes Dashboard...$(NC)"
	@./scripts/deploy-dashboard.sh

delete-dashboard: ## Delete Kubernetes Dashboard from the cluster
	@echo "$(YELLOW)Deleting Kubernetes Dashboard...$(NC)"
	@kubectl delete namespace kubernetes-dashboard --ignore-not-found=true
	@kubectl delete clusterrolebinding admin-user --ignore-not-found=true
	@rm -f dashboard-token.txt
	@echo "$(GREEN)Dashboard deleted successfully$(NC)"

dashboard-proxy: ## Start kubectl proxy for dashboard access
	@echo "$(GREEN)Starting kubectl proxy for dashboard access...$(NC)"
	@echo "$(YELLOW)Dashboard will be available at:$(NC)"
	@echo "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
	@echo ""
	@echo "$(YELLOW)Press Ctrl+C to stop the proxy$(NC)"
	@echo ""
	@kubectl proxy

dashboard-token: ## Display the dashboard access token
	@if [ -f dashboard-token.txt ]; then \
		echo "$(GREEN)Dashboard Access Token:$(NC)"; \
		echo "========================================"; \
		cat dashboard-token.txt; \
		echo "========================================"; \
	else \
		echo "$(YELLOW)Token file not found. Retrieving from cluster...$(NC)"; \
		kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 --decode; \
		echo ""; \
	fi

dashboard-url: ## Display the dashboard URL
	@echo "$(GREEN)Kubernetes Dashboard URL:$(NC)"
	@echo "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
	@echo ""
	@echo "$(YELLOW)Make sure kubectl proxy is running:$(NC)"
	@echo "  make dashboard-proxy"

test-proxy: ## Start test proxy (no authentication) for development
	@echo "$(GREEN)Starting test proxy (no auth)...$(NC)"
	@./scripts/setup-test-proxy.sh

test-proxy-auth: ## Start test proxy with authentication for development
	@echo "$(GREEN)Starting test proxy with authentication...$(NC)"
	@./scripts/setup-test-proxy.sh --auth

cleanup-test-proxy: ## Stop and remove test proxy
	@echo "$(GREEN)Cleaning up test proxy...$(NC)"
	@./scripts/cleanup-test-proxy.sh
