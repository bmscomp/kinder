# Kind Kubernetes Cluster with Corporate Proxy Support

Automated deployment of a 3-node Kind Kubernetes cluster with configurable corporate proxy support for macOS.

## Cluster Configuration

- **Cluster Name**: celine
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

**Option A: Direct Proxy (Basic/Digest Auth)**

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

**Option B: CNTLM (NTLM Authentication)**

For corporate proxies requiring NTLM authentication:

```bash
# Point to CNTLM running on Docker bridge
HTTP_PROXY=http://172.17.0.1:3128
HTTPS_PROXY=http://172.17.0.1:3128
NO_PROXY=localhost,127.0.0.1,127.0.0.*,172.17.*,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

> **📖 CNTLM Setup**: See [`proxy/CNTLM_SETUP.md`](proxy/CNTLM_SETUP.md) for complete CNTLM installation and configuration guide.

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

## Testing with Local Proxy

To test proxy configuration without a real corporate proxy, use the built-in test proxy:

```bash
# Start local test proxy
make test-proxy

# Create cluster (automatically uses test proxy)
make create-cluster

# Test image pull
kubectl run test-nginx --image=nginx:latest --restart=Never
kubectl get pod test-nginx

# Cleanup
kubectl delete pod test-nginx
make cleanup-test-proxy
```

> **📖 Full Testing Guide**: See [`TESTING_PROXY.md`](TESTING_PROXY.md) for comprehensive testing instructions.

## Makefile Commands

### Cluster Management

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make create-cluster` | Create and deploy the Kind cluster |
| `make delete-cluster` | Delete the Kind cluster |
| `make restart-cluster` | Delete and recreate the cluster |
| `make status` | Show cluster status and info |
| `make set-context` | Set kubectl context to the Kind cluster |
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
| `make configure-containerd-proxy` | Configure containerd proxy on all nodes |
| `make check-containerd-proxy` | Check containerd proxy configuration on all nodes |
| `make restart-containerd` | Restart containerd service on all nodes |
| `make load-image IMAGE=name:tag` | Load a Docker image into the cluster |
| `make install-deps` | Install required dependencies |
| `make check-deps` | Check if dependencies are installed |

### Kubernetes Dashboard

| Command | Description |
|---------|-------------|
| `make deploy-dashboard` | Deploy Kubernetes Dashboard to the cluster |
| `make delete-dashboard` | Delete Kubernetes Dashboard from the cluster |
| `make dashboard-proxy` | Start kubectl proxy for dashboard access |
| `make dashboard-token` | Display the dashboard access token |
| `make dashboard-url` | Display the dashboard URL |

### Testing & Development

| Command | Description |
|---------|-------------|
| `make test-proxy` | Start local test proxy (no auth) for development |
| `make test-proxy-auth` | Start local test proxy with authentication |
| `make cleanup-test-proxy` | Stop and remove test proxy |

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
- `celine-control-plane` (paris)
- `celine-worker` (berlin)
- `celine-worker2` (london)

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
kind load docker-image myapp:latest --name celine
```

### Using Kubernetes Dashboard

Deploy and access the Kubernetes Dashboard for a web-based UI.

> **Quick Start**: See [`DASHBOARD_QUICKSTART.md`](DASHBOARD_QUICKSTART.md) for a 3-minute setup guide.
> 
> **Full Guide**: See [`DASHBOARD_GUIDE.md`](DASHBOARD_GUIDE.md) for comprehensive documentation.

#### Deploy Dashboard

```bash
make deploy-dashboard
```

This will:
- Deploy Kubernetes Dashboard v2.7.0
- Create an admin service account with cluster-admin privileges
- Generate and save an access token to `dashboard-token.txt`

#### Access Dashboard

**Step 1: Start the proxy**

```bash
make dashboard-proxy
```

Keep this terminal running.

**Step 2: Open the dashboard in your browser**

```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

Or get the URL with:
```bash
make dashboard-url
```

**Step 3: Login with token**

Get your access token:
```bash
make dashboard-token
```

Copy the token and paste it into the dashboard login page.

#### Dashboard Management

```bash
# View the access token
make dashboard-token

# Get the dashboard URL
make dashboard-url

# Delete the dashboard
make delete-dashboard
```

**Note**: The dashboard provides a visual interface to:
- View cluster resources (pods, deployments, services)
- Monitor resource usage
- View logs and events
- Execute commands in containers
- Manage workloads

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

### Kubectl Cannot Connect to Cluster

```
Error: couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
```

**Cause**: kubectl is not configured to use the Kind cluster context.

**Solutions**:

1. **Set the correct context**:
   ```bash
   make set-context
   # or
   kubectl config use-context kind-celine
   ```

2. **Verify cluster exists**:
   ```bash
   kind get clusters
   # Should show: celine
   ```

3. **Check current context**:
   ```bash
   kubectl config current-context
   # Should show: kind-celine
   ```

4. **List all contexts**:
   ```bash
   kubectl config get-contexts
   ```

5. **If cluster doesn't exist, create it**:
   ```bash
   make create-cluster
   ```

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

You can check the proxy configuration on all nodes at once:

```bash
# Check containerd proxy configuration on all nodes
make check-containerd-proxy
```

Or manually check a specific node:

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

#### Reconfigure Containerd Proxy After Cluster Creation

If you need to update proxy settings after the cluster is already running:

```bash
# 1. Update your proxy configuration
vi proxy/proxy.env

# 2. Apply the new configuration to all nodes
make configure-containerd-proxy

# 3. Verify the configuration was applied
make check-containerd-proxy
```

This is useful when:
- Your proxy credentials change
- Your proxy URL changes
- You need to add or modify NO_PROXY entries

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
├── README.md                          # Main documentation
├── DASHBOARD_QUICKSTART.md            # Dashboard 3-minute setup guide
├── DASHBOARD_GUIDE.md                 # Kubernetes Dashboard full guide
├── CONTAINERD_PROXY_USAGE.md          # Containerd proxy configuration guide
├── TESTING_PROXY.md                   # Test proxy setup and usage guide
├── .gitignore                         # Git ignore rules
├── config/
│   └── kind-cluster-config.yaml      # Kind cluster configuration
├── proxy/
│   ├── proxy.env.example             # Proxy configuration template
│   ├── proxy.env                     # Your proxy settings (git-ignored)
│   ├── README.md                     # Proxy documentation
│   └── CNTLM_SETUP.md                # CNTLM setup guide for NTLM proxies
└── scripts/
    ├── deploy-kind-cluster.sh        # Main cluster deployment script
    ├── deploy-dashboard.sh           # Dashboard deployment script
    ├── setup-test-proxy.sh           # Setup local test proxy
    └── cleanup-test-proxy.sh         # Cleanup test proxy
```

## Files Description

- **`config/kind-cluster-config.yaml`**: Kind cluster configuration with 3 nodes
- **`scripts/deploy-kind-cluster.sh`**: Main deployment script with enhanced proxy support
- **`scripts/deploy-dashboard.sh`**: Kubernetes Dashboard deployment script
- **`proxy/proxy.env.example`**: Template for proxy configuration (includes CNTLM example)
- **`proxy/proxy.env`**: Your actual proxy settings (created by `make configure-proxy`)
- **`proxy/README.md`**: Detailed proxy configuration and troubleshooting guide
- **`proxy/CNTLM_SETUP.md`**: Complete CNTLM setup guide for NTLM authentication proxies
- **`dashboard-token.txt`**: Dashboard access token (git-ignored, created by dashboard deployment)
- **`Makefile`**: Convenient commands for cluster management
- **`README.md`**: Main documentation
- **`DASHBOARD_QUICKSTART.md`**: Quick 3-minute dashboard setup guide
- **`DASHBOARD_GUIDE.md`**: Comprehensive Kubernetes Dashboard guide
- **`CONTAINERD_PROXY_USAGE.md`**: Containerd proxy configuration reference
- **`TESTING_PROXY.md`**: Complete guide for testing with local Squid proxy
- **`scripts/setup-test-proxy.sh`**: Script to start local test proxy (Squid in Docker)
- **`scripts/cleanup-test-proxy.sh`**: Script to cleanup test proxy

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
