# Kind Kubernetes Cluster with Corporate Proxy Support

Automated deployment of a 3-node Kind Kubernetes cluster with configurable corporate proxy support for macOS.

## Cluster Configuration

- **Cluster Name**: corporate-cluster
- **Nodes**: 3 nodes with custom names
  - **paris** (control-plane) - 4 CPUs, 10GB RAM
  - **berlin** (worker) - 4 CPUs, 10GB RAM
  - **london** (worker) - 4 CPUs, 10GB RAM
- **Kubernetes Version**: v1.28.0
- **Proxy Support**: Configurable HTTP/HTTPS proxy for corporate environments

## Prerequisites

- macOS
- Docker Desktop installed and running
- Homebrew (for installing dependencies)

## Quick Start

### 1. Install Dependencies

```bash
make install-deps
```

This will install:
- `kind` (Kubernetes in Docker)
- `kubectl` (Kubernetes CLI)

### 2. Configure Proxy (Optional)

If you're behind a corporate proxy, create the proxy configuration:

```bash
make configure-proxy
```

Then edit `.proxy-config` with your proxy settings:

```bash
# Corporate Proxy Configuration
HTTP_PROXY=http://proxy.company.com:8080
HTTPS_PROXY=http://proxy.company.com:8080
NO_PROXY=localhost,127.0.0.1,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

**Important for macOS Docker Desktop users**: Also configure proxy settings in Docker Desktop:
- Open Docker Desktop
- Go to Settings > Resources > Proxies
- Enable manual proxy configuration
- Enter your proxy details

### 3. Create the Cluster

```bash
make create-cluster
```

This will:
- Check Docker is running
- Load proxy configuration (if exists)
- Create a 3-node Kind cluster
- Configure each node with 4 CPUs and 10GB memory
- Apply proxy settings to containerd (if configured)
- Label nodes with city names (paris, berlin, london)
- Verify the cluster is ready

## Makefile Commands

### Cluster Management

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make create-cluster` | Create and deploy the Kind cluster |
| `make delete-cluster` | Delete the Kind cluster |
| `make restart-cluster` | Delete and recreate the cluster |
| `make status` | Show cluster status and info |
| `make clean` | Clean up cluster and generated files |

### Cluster Information

| Command | Description |
|---------|-------------|
| `make get-nodes` | List all nodes with labels |
| `make get-pods` | List all pods in all namespaces |
| `make get-services` | List all services |

### Node Access

| Command | Description |
|---------|-------------|
| `make shell-paris` | Open shell in paris node (control-plane) |
| `make shell-berlin` | Open shell in berlin node (worker) |
| `make shell-london` | Open shell in london node (worker) |

### Debugging

| Command | Description |
|---------|-------------|
| `make logs-paris` | Show logs from paris node |
| `make logs-berlin` | Show logs from berlin node |
| `make logs-london` | Show logs from london node |
| `make inspect-paris` | Inspect paris node container |
| `make inspect-berlin` | Inspect berlin node container |
| `make inspect-london` | Inspect london node container |
| `make export-logs` | Export all cluster logs to ./cluster-logs |

### Utilities

| Command | Description |
|---------|-------------|
| `make configure-proxy` | Create proxy configuration template |
| `make load-image IMAGE=name:tag` | Load a Docker image into the cluster |
| `make install-deps` | Install required dependencies |
| `make check-deps` | Check if dependencies are installed |

## Manual Usage

You can also run the deployment script directly:

```bash
./scripts/deploy-kind-cluster.sh
```

## Verifying the Cluster

After creation, verify your cluster:

```bash
# Check nodes
kubectl get nodes -o wide

# Check node labels
kubectl get nodes --show-labels

# Check system pods
kubectl get pods -A

# Get cluster info
kubectl cluster-info
```

Expected output should show 3 nodes:
- `corporate-cluster-control-plane` (paris)
- `corporate-cluster-worker` (berlin)
- `corporate-cluster-worker2` (london)

## Working with the Cluster

### Deploy a Sample Application

```bash
# Create a deployment
kubectl create deployment nginx --image=nginx

# Expose it as a service
kubectl expose deployment nginx --port=80 --type=NodePort

# Check the service
kubectl get svc nginx
```

### Access Services

Since Kind runs in Docker, you can port-forward to access services:

```bash
kubectl port-forward service/nginx 8080:80
```

Then access at http://localhost:8080

### Load Local Docker Images

```bash
# Build your image
docker build -t myapp:latest .

# Load into Kind cluster
make load-image IMAGE=myapp:latest

# Or directly:
kind load docker-image myapp:latest --name corporate-cluster
```

## Proxy Configuration Details

The deployment script configures proxies at multiple levels:

1. **Host Environment**: Exports `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`
2. **Docker Daemon**: Requires manual configuration in Docker Desktop on macOS
3. **Containerd**: Configures proxy for container runtime inside each node

### Proxy Configuration File Format

The `.proxy-config` file should contain:

```bash
HTTP_PROXY=http://proxy.company.com:8080
HTTPS_PROXY=http://proxy.company.com:8080
NO_PROXY=localhost,127.0.0.1,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

**Note**: Adjust the `NO_PROXY` list to include your internal network ranges.

## Troubleshooting

### Docker Not Running

```
Error: Docker is not running
```

**Solution**: Start Docker Desktop and wait for it to be fully running.

### Cluster Creation Fails

```
Error: failed to create cluster
```

**Solutions**:
1. Check Docker has enough resources (Settings > Resources)
2. Delete existing cluster: `make delete-cluster`
3. Check Docker proxy settings if behind a proxy
4. Review logs: `docker logs <container-name>`

### Nodes Not Ready

```bash
# Check node status
kubectl get nodes

# Describe node for details
kubectl describe node <node-name>

# Check system pods
kubectl get pods -n kube-system
```

### Proxy Issues

If containers can't pull images:

1. Verify `.proxy-config` settings
2. Check Docker Desktop proxy configuration
3. Verify `NO_PROXY` includes cluster networks
4. Check containerd proxy: `make shell-paris` then check `/etc/systemd/system/containerd.service.d/http-proxy.conf`

### Resource Constraints

If nodes are slow or unresponsive:

1. Check Docker Desktop resource allocation (Settings > Resources)
2. Increase Docker memory/CPU limits
3. Reduce node count or resources in `deploy-kind-cluster.sh`

## Project Structure

```
kinder/
├── Makefile                           # Cluster management commands
├── README.md                          # This documentation
├── .proxy-config                      # Proxy configuration (optional)
├── .gitignore                         # Git ignore rules
├── config/
│   └── kind-cluster-config.yaml      # Kind cluster configuration
└── scripts/
    └── deploy-kind-cluster.sh        # Main deployment script
```

## Files Description

- **`config/kind-cluster-config.yaml`**: Kind cluster configuration with 3 nodes
- **`scripts/deploy-kind-cluster.sh`**: Main deployment script with proxy support
- **`Makefile`**: Convenient commands for cluster management
- **`.proxy-config`**: Proxy configuration (created by `make configure-proxy`)
- **`README.md`**: This documentation

## Customization

### Change Node Resources

Edit `scripts/deploy-kind-cluster.sh`:

```bash
NODE_MEMORY="10240m"  # Change memory (e.g., "8192m" for 8GB)
NODE_CPUS="4"         # Change CPU count (e.g., "2")
```

### Change Node Names

Edit `config/kind-cluster-config.yaml` and update the `node-labels` and `labels` sections.

### Change Kubernetes Version

Edit `config/kind-cluster-config.yaml` and update the `image` field:

```yaml
image: kindest/node:v1.29.0  # Use different version
```

## Cleanup

To completely remove the cluster and all resources:

```bash
make clean
```

This will:
- Delete the Kind cluster
- Remove exported logs
- Keep configuration files for reuse

## Additional Resources

- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Desktop for Mac](https://docs.docker.com/desktop/mac/)

## License

This project is provided as-is for educational and development purposes
