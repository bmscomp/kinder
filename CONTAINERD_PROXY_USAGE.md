# Containerd Proxy Configuration - Quick Reference

This guide shows how to use the new Makefile commands for managing containerd proxy configuration on all cluster nodes.

## Prerequisites

- Cluster must be running (`make create-cluster`)
- Proxy configuration file must exist (`proxy/proxy.env`)

## Commands Overview

| Command | Purpose |
|---------|---------|
| `make configure-containerd-proxy` | Apply proxy settings to all nodes |
| `make check-containerd-proxy` | View current proxy configuration |
| `make restart-containerd` | Restart containerd service |

## Common Workflows

### 1. Initial Proxy Setup (During Cluster Creation)

The deployment script automatically configures containerd proxy during cluster creation:

```bash
# Create proxy configuration
make configure-proxy

# Edit with your settings
vi proxy/proxy.env

# Create cluster (proxy is auto-configured)
make create-cluster
```

### 2. Update Proxy Settings After Cluster Creation

If you need to change proxy settings on an existing cluster:

```bash
# Step 1: Update proxy configuration
vi proxy/proxy.env

# Step 2: Apply to all nodes
make configure-containerd-proxy

# Step 3: Verify the changes
make check-containerd-proxy
```

**Example Output:**
```
Configuring containerd proxy on all cluster nodes...
Configuring celine-control-plane...
✓ celine-control-plane configured
Configuring celine-worker...
✓ celine-worker configured
Configuring celine-worker2...
✓ celine-worker2 configured
Containerd proxy configuration completed for all nodes
```

### 3. Verify Proxy Configuration

Check the proxy configuration on all nodes:

```bash
make check-containerd-proxy
```

**Example Output:**
```
Checking containerd proxy configuration on all nodes...

=== celine-control-plane ===
Containerd proxy config:
[Service]
Environment="HTTP_PROXY=http://proxy.company.com:8080"
Environment="HTTPS_PROXY=http://proxy.company.com:8080"
Environment="NO_PROXY=localhost,127.0.0.1,..."

Kubelet proxy config:
[Service]
Environment="HTTP_PROXY=http://proxy.company.com:8080"
...

Environment variables:
HTTP_PROXY=http://proxy.company.com:8080
HTTPS_PROXY=http://proxy.company.com:8080
...
```

### 4. Restart Containerd Service

If you manually modified configuration files, restart containerd:

```bash
make restart-containerd
```

## What Gets Configured

When you run `make configure-containerd-proxy`, the following happens on **all three nodes** (paris, berlin, london):

1. **Containerd systemd service** (`/etc/systemd/system/containerd.service.d/http-proxy.conf`)
   - Sets HTTP_PROXY, HTTPS_PROXY, NO_PROXY environment variables
   - Allows containerd to pull images through the proxy

2. **Kubelet systemd service** (`/etc/systemd/system/kubelet.service.d/http-proxy.conf`)
   - Sets proxy environment variables for kubelet
   - Ensures Kubernetes components can communicate through proxy

3. **Node environment** (`/etc/environment`)
   - Sets system-wide proxy variables
   - Affects all processes running in the node

4. **Service restart**
   - Reloads systemd daemon
   - Restarts containerd to apply changes

## Troubleshooting

### Proxy Configuration Not Applied

If proxy settings don't seem to work:

```bash
# 1. Verify proxy.env exists and has correct values
make show-proxy

# 2. Reconfigure all nodes
make configure-containerd-proxy

# 3. Check configuration was applied
make check-containerd-proxy

# 4. Test image pull
kubectl run test-nginx --image=nginx:latest --restart=Never
kubectl get pod test-nginx
```

### Authentication Issues

If your proxy requires authentication:

```bash
# Edit proxy.env and add credentials
vi proxy/proxy.env

# Add these lines:
# PROXY_USER=your-username
# PROXY_PASS=your-password

# Reapply configuration
make configure-containerd-proxy
```

The script automatically constructs authenticated URLs like:
`http://username:password@proxy.company.com:8080`

### Check Individual Node

To manually inspect a specific node:

```bash
# Open shell in paris node
make shell-paris

# Check containerd config
cat /etc/systemd/system/containerd.service.d/http-proxy.conf

# Check if containerd is running
systemctl status containerd

# Exit
exit
```

## Use Cases

### Use Case 1: Proxy Credentials Rotated

Your company rotates proxy passwords monthly:

```bash
# Update credentials in proxy.env
vi proxy/proxy.env  # Update PROXY_PASS

# Apply to all nodes
make configure-containerd-proxy

# Verify
make check-containerd-proxy
```

### Use Case 2: Add Internal Network to NO_PROXY

You need to add a new internal network range:

```bash
# Update NO_PROXY in proxy.env
vi proxy/proxy.env  # Add new CIDR range

# Apply to all nodes
make configure-containerd-proxy

# Verify
make check-containerd-proxy
```

### Use Case 3: Switch Proxy Servers

Your company migrates to a new proxy server:

```bash
# Update proxy URLs
vi proxy/proxy.env  # Change HTTP_PROXY and HTTPS_PROXY

# Apply to all nodes
make configure-containerd-proxy

# Verify
make check-containerd-proxy

# Test with a pod
kubectl run test --image=nginx --restart=Never
kubectl get pod test
kubectl delete pod test
```

## Integration with Existing Workflow

These commands integrate seamlessly with your existing workflow:

```bash
# Standard cluster creation (proxy auto-configured)
make create-cluster

# Later, if proxy changes...
make configure-containerd-proxy

# Check status
make status
make check-containerd-proxy

# Continue working
kubectl get nodes
kubectl get pods -A
```

## Security Notes

- Proxy passwords are handled securely
- The `configure-containerd-proxy` command reads from `proxy/proxy.env` which is git-ignored
- Passwords are embedded in systemd service files inside the nodes
- Use `make check-containerd-proxy` carefully in shared environments (it displays passwords)

## Additional Resources

- Main documentation: `README.md`
- Proxy details: `proxy/README.md`
- Deployment script: `scripts/deploy-kind-cluster.sh`
