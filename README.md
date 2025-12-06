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

If you're behind a corporate proxy, follow these steps:

#### Step 1: Create Proxy Configuration

```bash
make configure-proxy
```

This creates `proxy/proxy.env` from the template.

#### Step 2: Edit Proxy Settings

Edit `proxy/proxy.env` with your corporate proxy details:

```bash
# Required settings
HTTP_PROXY=http://proxy.company.com:8080
HTTPS_PROXY=http://proxy.company.com:8080
NO_PROXY=localhost,127.0.0.1,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16

# Optional: If authentication is required
PROXY_USER=your-username
PROXY_PASS=your-password
```

#### Step 3: Configure Docker Desktop (macOS)

1. Open Docker Desktop
2. Go to **Settings** → **Resources** → **Proxies**
3. Enable **Manual proxy configuration**
4. Enter:
   - Web Server (HTTP): `http://proxy.company.com:8080`
   - Secure Web Server (HTTPS): `http://proxy.company.com:8080`
5. Click **Apply & Restart**

**Note**: See the [Proxy Configuration Details](#proxy-configuration-details) section below for more information.

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
| `make configure-proxy` | Create proxy configuration from template |
| `make show-proxy` | Show current proxy configuration |
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

The deployment script configures proxies at multiple levels to ensure Kind can pull images behind a corporate proxy:

1. **Host Environment**: Exports `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`
2. **Docker Daemon**: Requires manual configuration in Docker Desktop on macOS
3. **Containerd**: Configures proxy for container runtime inside each node
4. **Kubelet**: Configures proxy for Kubernetes node agent
5. **Node Environment**: Sets proxy variables in `/etc/environment`

### Proxy Configuration File Format

The `proxy/proxy.env` file should contain:

```bash
# Basic proxy configuration
HTTP_PROXY=http://proxy.company.com:8080
HTTPS_PROXY=http://proxy.company.com:8080
NO_PROXY=localhost,127.0.0.1,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16

# Optional: Proxy authentication
PROXY_USER=your-username
PROXY_PASS=your-password
```

**Note**: 
- Adjust the `NO_PROXY` list to include your internal network ranges
- The script automatically constructs authenticated URLs if credentials are provided
- Passwords are masked in log output for security

### Verify Proxy is Working

After cluster creation, test that images can be pulled through the proxy:

```bash
# Deploy a test pod
kubectl run test-nginx --image=nginx:latest --restart=Never

# Wait a moment, then check status
kubectl get pod test-nginx

# Should show "Running" status
# If it shows "ImagePullBackOff", see troubleshooting below
```

Check the pod details:

```bash
kubectl describe pod test-nginx
```

Look for events showing successful image pull. Clean up:

```bash
kubectl delete pod test-nginx
```

### View Current Proxy Configuration

```bash
make show-proxy
```

### Common Proxy Configurations

#### Basic Proxy (No Authentication)

```bash
HTTP_PROXY=http://proxy.company.com:8080
HTTPS_PROXY=http://proxy.company.com:8080
NO_PROXY=localhost,127.0.0.1,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

#### Proxy with Authentication

```bash
HTTP_PROXY=http://proxy.company.com:8080
HTTPS_PROXY=http://proxy.company.com:8080
NO_PROXY=localhost,127.0.0.1,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
PROXY_USER=john.doe
PROXY_PASS=SecurePassword123
```

#### Different HTTP and HTTPS Proxies

```bash
HTTP_PROXY=http://http-proxy.company.com:8080
HTTPS_PROXY=http://https-proxy.company.com:8443
NO_PROXY=localhost,127.0.0.1,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

### Proxy Security Best Practices

1. **Never commit `proxy/proxy.env`** - It's in `.gitignore` for security
2. **Use strong passwords** - If authentication is required
3. **Rotate credentials** - Change passwords regularly
4. **Limit access** - Restrict who can read `proxy/proxy.env`
5. **Consider alternatives** - Use environment variables instead of storing passwords

For additional proxy documentation, see `proxy/README.md`.

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

#### Check Proxy Configuration in Nodes

```bash
# Open shell in control-plane node
make shell-paris

# Check containerd proxy
cat /etc/systemd/system/containerd.service.d/http-proxy.conf

# Check kubelet proxy
cat /etc/systemd/system/kubelet.service.d/http-proxy.conf

# Check environment variables
cat /etc/environment

# Exit node
exit
```

#### Verify Docker Desktop Proxy

- Settings → Resources → Proxies
- Ensure proxy URLs are correct
- Try toggling off and on, then Apply & Restart

#### Check NO_PROXY Includes Cluster Networks

```
NO_PROXY should include:
- localhost,127.0.0.1
- .local,.svc,.cluster.local
- 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
- 10.96.0.0/12 (Kubernetes service network)
- 10.244.0.0/16 (Kubernetes pod network)
```

#### Test Proxy from Host

Before creating the cluster, test proxy from your Mac:

```bash
# Source the proxy configuration
source proxy/proxy.env

# Test HTTP connection
curl -I http://registry-1.docker.io/v2/

# Test HTTPS connection
curl -I https://registry-1.docker.io/v2/

# Should return 200 or 401 (authentication required)
# Should NOT return connection errors
```

#### Proxy Authentication Issues

If your proxy requires authentication:

1. Ensure `PROXY_USER` and `PROXY_PASS` are set in `proxy/proxy.env`
2. The script automatically constructs authenticated URLs
3. Check logs during cluster creation for authentication errors
4. Passwords are masked in output for security

#### SSL/TLS Certificate Issues

If you see SSL certificate errors:

1. Your proxy might be intercepting SSL traffic
2. You may need to install your corporate CA certificate
3. Contact your IT department for the CA certificate
4. Consider adding `HTTPS_PROXY` with your proxy's certificate

#### Quick Checks

- View current proxy settings: `make show-proxy`
- Verify `proxy/proxy.env` settings
- Check Docker Desktop proxy configuration (Settings > Resources > Proxies)

### Resource Constraints

If nodes are slow or unresponsive:

1. Check Docker Desktop resource allocation (Settings > Resources)
2. Increase Docker memory/CPU limits
3. Reduce node count or resources in `deploy-kind-cluster.sh`

## Project Structure

```
kinder/
├── Makefile                           # Cluster management commands
├── README.md                          # This documentation (includes proxy setup)
├── .gitignore                         # Git ignore rules
├── config/
│   └── kind-cluster-config.yaml      # Kind cluster configuration
├── proxy/
│   ├── proxy.env.example             # Proxy configuration template
│   ├── proxy.env                     # Your proxy settings (git-ignored)
│   └── README.md                     # Additional proxy documentation
└── scripts/
    └── deploy-kind-cluster.sh        # Main deployment script
```

## Files Description

- **`config/kind-cluster-config.yaml`**: Kind cluster configuration with 3 nodes
- **`scripts/deploy-kind-cluster.sh`**: Main deployment script with enhanced proxy support
- **`proxy/proxy.env.example`**: Template for proxy configuration
- **`proxy/proxy.env`**: Your actual proxy settings (created by `make configure-proxy`)
- **`proxy/README.md`**: Detailed proxy configuration and troubleshooting guide
- **`Makefile`**: Convenient commands for cluster management
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
