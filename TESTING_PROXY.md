# Testing Proxy Configuration

This guide explains how to test the proxy configuration using a local Squid proxy that simulates a corporate proxy environment.

## Overview

The test proxy setup allows you to:
- **Simulate corporate proxy** without needing actual corporate network access
- **Test proxy configuration** before deploying to production
- **Verify containerd proxy** settings work correctly
- **Test both authenticated and non-authenticated** proxy scenarios
- **Debug proxy issues** in a controlled environment

## Quick Start

### Option 1: Proxy Without Authentication

```bash
# Start test proxy (no auth, port 3128)
./scripts/setup-test-proxy.sh

# Create Kind cluster
make create-cluster

# Test image pull
kubectl run test-nginx --image=nginx:latest --restart=Never
kubectl get pod test-nginx
kubectl delete pod test-nginx

# Cleanup
./scripts/cleanup-test-proxy.sh
```

### Option 2: Proxy With Authentication

```bash
# Start test proxy with auth (port 3129)
./scripts/setup-test-proxy.sh --auth

# Create Kind cluster
make create-cluster

# Test image pull
kubectl run test-nginx --image=nginx:latest --restart=Never
kubectl get pod test-nginx
kubectl delete pod test-nginx

# Cleanup
./scripts/cleanup-test-proxy.sh
```

## Detailed Setup

### Step 1: Start Test Proxy

The setup script creates a Docker container running Squid proxy:

```bash
# Without authentication (default)
./scripts/setup-test-proxy.sh

# With authentication
./scripts/setup-test-proxy.sh --auth

# Show help
./scripts/setup-test-proxy.sh --help
```

**What it does:**
1. Creates Squid configuration files
2. Starts Squid proxy in Docker container
3. Tests proxy connectivity
4. Creates `proxy/proxy.env` with correct settings
5. Shows usage instructions

**Proxy Details:**

| Mode | Port | Authentication | Credentials |
|------|------|----------------|-------------|
| No Auth | 3128 | None | N/A |
| With Auth | 3129 | Basic Auth | testuser / testpass |

### Step 2: Verify Proxy is Running

```bash
# Check container status
docker ps | grep test-corporate-proxy

# View proxy logs
docker logs test-corporate-proxy

# Follow logs in real-time
docker logs -f test-corporate-proxy
```

### Step 3: Test Proxy Manually

**Without authentication:**
```bash
# Test HTTP request
curl -x http://localhost:3128 http://www.google.com

# Test HTTPS request
curl -x http://localhost:3128 https://www.google.com

# Test from Docker container
docker run --rm -e http_proxy=http://host.docker.internal:3128 alpine wget -O- http://www.google.com
```

**With authentication:**
```bash
# Test HTTP request
curl -x http://testuser:testpass@localhost:3129 http://www.google.com

# Test HTTPS request
curl -x http://testuser:testpass@localhost:3129 https://www.google.com

# Test from Docker container
docker run --rm -e http_proxy=http://testuser:testpass@host.docker.internal:3129 alpine wget -O- http://www.google.com
```

### Step 4: Create Kind Cluster

The `proxy/proxy.env` file is automatically created by the setup script:

```bash
# Create cluster (uses proxy/proxy.env)
make create-cluster
```

The deployment script will:
1. Load proxy settings from `proxy/proxy.env`
2. Configure containerd on all nodes
3. Configure kubelet on all nodes
4. Set environment variables

### Step 5: Verify Cluster Uses Proxy

**Check containerd configuration:**
```bash
make check-containerd-proxy
```

**Expected output:**
```
=== celine-control-plane ===
Containerd proxy config:
[Service]
Environment="HTTP_PROXY=http://localhost:3128"
Environment="HTTPS_PROXY=http://localhost:3128"
Environment="NO_PROXY=localhost,127.0.0.1,..."
```

**Test image pull:**
```bash
# Deploy test pod
kubectl run test-nginx --image=nginx:latest --restart=Never

# Check status (should be Running)
kubectl get pod test-nginx

# Check events (should show successful image pull)
kubectl describe pod test-nginx | grep -A 10 Events

# Clean up
kubectl delete pod test-nginx
```

**Monitor proxy logs during image pull:**
```bash
# In another terminal, watch proxy logs
docker logs -f test-corporate-proxy

# You should see requests like:
# TCP_MISS/200 ... CONNECT registry-1.docker.io:443
```

## Testing Scenarios

### Scenario 1: Basic Proxy Functionality

**Test:** Verify Kind can pull images through proxy

```bash
# Start proxy
./scripts/setup-test-proxy.sh

# Create cluster
make create-cluster

# Pull various images
kubectl run test-nginx --image=nginx:latest --restart=Never
kubectl run test-alpine --image=alpine:latest --restart=Never --command -- sleep 3600
kubectl run test-busybox --image=busybox:latest --restart=Never --command -- sleep 3600

# Check all pods are running
kubectl get pods

# Cleanup
kubectl delete pod test-nginx test-alpine test-busybox
```

### Scenario 2: Authenticated Proxy

**Test:** Verify authentication credentials work

```bash
# Start proxy with auth
./scripts/setup-test-proxy.sh --auth

# Create cluster
make create-cluster

# Test image pull
kubectl run test-nginx --image=nginx:latest --restart=Never
kubectl get pod test-nginx

# Check proxy logs show authenticated requests
docker logs test-corporate-proxy | grep testuser

# Cleanup
kubectl delete pod test-nginx
```

### Scenario 3: Proxy Configuration Update

**Test:** Update proxy settings on running cluster

```bash
# Start proxy
./scripts/setup-test-proxy.sh

# Create cluster
make create-cluster

# Modify proxy settings
vi proxy/proxy.env

# Reconfigure all nodes
make configure-containerd-proxy

# Verify new configuration
make check-containerd-proxy

# Test image pull still works
kubectl run test-nginx --image=nginx:latest --restart=Never
kubectl get pod test-nginx
kubectl delete pod test-nginx
```

### Scenario 4: NO_PROXY Testing

**Test:** Verify internal cluster communication bypasses proxy

```bash
# Start proxy
./scripts/setup-test-proxy.sh

# Create cluster
make create-cluster

# Deploy service
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80

# Test internal communication (should not go through proxy)
kubectl run test-curl --image=curlimages/curl --rm -it --restart=Never -- curl http://nginx

# Check proxy logs - should NOT show internal requests
docker logs test-corporate-proxy | grep nginx
# (should be empty)
```

### Scenario 5: Dashboard with Proxy

**Test:** Deploy Kubernetes Dashboard through proxy

```bash
# Start proxy
./scripts/setup-test-proxy.sh

# Create cluster
make create-cluster

# Deploy dashboard
make deploy-dashboard

# Check dashboard pods pulled images successfully
kubectl get pods -n kubernetes-dashboard

# Access dashboard
make dashboard-proxy
# Open browser and login
```

## Troubleshooting

### Proxy Container Won't Start

**Check Docker:**
```bash
docker info
docker ps -a | grep test-corporate-proxy
docker logs test-corporate-proxy
```

**Restart proxy:**
```bash
./scripts/cleanup-test-proxy.sh
./scripts/setup-test-proxy.sh
```

### Cluster Can't Pull Images

**Check proxy is running:**
```bash
docker ps | grep test-corporate-proxy
curl -x http://localhost:3128 http://www.google.com
```

**Check containerd configuration:**
```bash
make check-containerd-proxy
```

**Check proxy logs:**
```bash
docker logs -f test-corporate-proxy
```

**Reconfigure proxy:**
```bash
make configure-containerd-proxy
```

### Authentication Failures

**Verify credentials in proxy.env:**
```bash
cat proxy/proxy.env | grep PROXY_USER
cat proxy/proxy.env | grep PROXY_PASS
```

**Test authentication manually:**
```bash
curl -x http://testuser:testpass@localhost:3129 http://www.google.com
```

**Check proxy logs for auth errors:**
```bash
docker logs test-corporate-proxy | grep -i auth
```

### Proxy Logs Show No Activity

**Verify proxy.env is loaded:**
```bash
make show-proxy
```

**Check environment variables in nodes:**
```bash
make shell-paris
env | grep -i proxy
exit
```

**Verify containerd is using proxy:**
```bash
make check-containerd-proxy
```

## Advanced Testing

### Test Different Proxy Ports

Edit `scripts/setup-test-proxy.sh` to change ports:
```bash
PROXY_PORT="8080"  # Change from 3128
PROXY_AUTH_PORT="8081"  # Change from 3129
```

### Test Proxy Failures

**Simulate proxy downtime:**
```bash
# Stop proxy while cluster is running
docker stop test-corporate-proxy

# Try to pull image (should fail)
kubectl run test-fail --image=nginx:latest --restart=Never

# Check pod status (should show ImagePullBackOff)
kubectl get pod test-fail
kubectl describe pod test-fail

# Restart proxy
docker start test-corporate-proxy

# Delete and recreate pod (should succeed now)
kubectl delete pod test-fail
kubectl run test-success --image=nginx:latest --restart=Never
kubectl get pod test-success
```

### Test Multiple Clusters

```bash
# Start proxy
./scripts/setup-test-proxy.sh

# Create first cluster
make create-cluster

# Test first cluster
kubectl run test1 --image=nginx --restart=Never

# Delete first cluster
make delete-cluster

# Create second cluster (reuses same proxy)
make create-cluster

# Test second cluster
kubectl run test2 --image=nginx --restart=Never
```

### Monitor Proxy Performance

```bash
# Watch proxy logs with timestamps
docker logs -f --timestamps test-corporate-proxy

# Check proxy container stats
docker stats test-corporate-proxy

# View detailed Squid access logs
docker exec test-corporate-proxy cat /var/log/squid/access.log

# View Squid cache logs
docker exec test-corporate-proxy cat /var/log/squid/cache.log
```

## Cleanup

### Remove Test Proxy

```bash
# Interactive cleanup (asks before removing proxy.env)
./scripts/cleanup-test-proxy.sh

# Manual cleanup
docker stop test-corporate-proxy
docker rm test-corporate-proxy
rm -rf test-proxy/
```

### Reset to Production Proxy

After testing, configure for your actual corporate proxy:

```bash
# Remove test configuration
./scripts/cleanup-test-proxy.sh

# Edit with production settings
vi proxy/proxy.env

# Or copy from example
cp proxy/proxy.env.example proxy/proxy.env
vi proxy/proxy.env
```

## Comparison: Test vs Production

| Aspect | Test Proxy | Production Proxy |
|--------|-----------|------------------|
| **Location** | Local Docker container | Corporate network |
| **Authentication** | testuser/testpass | Your credentials |
| **Port** | 3128 or 3129 | Varies (usually 8080, 3128) |
| **URL** | localhost | proxy.company.com |
| **SSL Inspection** | No | Maybe |
| **Logging** | Full access | Limited access |
| **Availability** | On-demand | Always available |

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Test Kind with Proxy

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup test proxy
        run: ./scripts/setup-test-proxy.sh
      
      - name: Create Kind cluster
        run: make create-cluster
      
      - name: Test image pull
        run: |
          kubectl run test-nginx --image=nginx:latest --restart=Never
          kubectl wait --for=condition=Ready pod/test-nginx --timeout=300s
          kubectl delete pod test-nginx
      
      - name: Cleanup
        if: always()
        run: ./scripts/cleanup-test-proxy.sh
```

## Best Practices

1. **Always test locally first** before deploying to production
2. **Monitor proxy logs** during testing to understand traffic patterns
3. **Test both auth and no-auth** scenarios if your environment might change
4. **Verify NO_PROXY** settings to ensure internal traffic doesn't go through proxy
5. **Test proxy failures** to ensure graceful degradation
6. **Clean up after testing** to avoid port conflicts
7. **Document your findings** for team members

## Quick Reference

```bash
# Setup
./scripts/setup-test-proxy.sh           # No auth, port 3128
./scripts/setup-test-proxy.sh --auth    # With auth, port 3129

# Test
curl -x http://localhost:3128 http://www.google.com
docker logs -f test-corporate-proxy

# Use with Kind
make create-cluster
make check-containerd-proxy
kubectl run test --image=nginx --restart=Never

# Cleanup
./scripts/cleanup-test-proxy.sh
```

## Additional Resources

- [Squid Proxy Documentation](http://www.squid-cache.org/Doc/)
- [Docker Proxy Configuration](https://docs.docker.com/network/proxy/)
- [Kind Proxy Support](https://kind.sigs.k8s.io/docs/user/configuration/#proxy)
- Main proxy documentation: [`proxy/README.md`](proxy/README.md)
- CNTLM setup: [`proxy/CNTLM_SETUP.md`](proxy/CNTLM_SETUP.md)
