# Zscaler Proxy Setup Guide for Kind

This guide explains how to configure Kind to work with Zscaler proxy for corporate environments.

## Overview

**Zscaler** is a cloud-based security platform that provides secure internet and SaaS access. It typically acts as a forward proxy with SSL inspection capabilities.

## Prerequisites

- macOS with Docker Desktop
- Zscaler Client Connector (formerly Zscaler App) installed
- Access to Zscaler proxy settings
- Admin access for certificate installation (if using SSL inspection)

## Quick Start

### Step 1: Find Your Zscaler Proxy Settings

**Option A: Auto-Detection (macOS - Recommended)**

```bash
# Automatically detect Zscaler settings
make detect-zscaler

# This will show your current proxy configuration and
# provide ready-to-use settings for proxy/proxy.env
```

**Option B: Check System Preferences (macOS)**

```bash
# Open Network settings
System Preferences → Network → Advanced → Proxies

# Look for:
# - Web Proxy (HTTP): gateway.zscaler.net or similar
# - Secure Web Proxy (HTTPS): gateway.zscaler.net or similar
# - Port: Usually 80, 9400, or 9480
```

**Option B: Check from Command Line**

```bash
# Check current proxy settings
scutil --proxy

# Look for HTTPProxy and HTTPSProxy values
```

**Option C: Common Zscaler Gateways**

- `gateway.zscaler.net` (most common)
- `gateway.zscalertwo.net`
- `gateway.zscalerthree.net`
- `gateway.zscloud.net`
- Custom company-specific gateway

Common ports: `80`, `9400`, `9480`

### Step 2: Configure Proxy Settings

```bash
# Copy the example configuration
cp proxy/proxy.env.example proxy/proxy.env

# Edit with your Zscaler settings
vi proxy/proxy.env
```

**Basic Zscaler Configuration:**

```bash
# Replace with your actual Zscaler gateway and port
HTTP_PROXY=http://gateway.zscaler.net:9400
http_proxy=http://gateway.zscaler.net:9400
HTTPS_PROXY=http://gateway.zscaler.net:9400
https_proxy=http://gateway.zscaler.net:9400

NO_PROXY=localhost,127.0.0.1,127.0.0.*,172.17.*,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16
no_proxy=localhost,127.0.0.1,127.0.0.*,172.17.*,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16
```

**With Authentication (if required):**

```bash
HTTP_PROXY=http://username:password@gateway.zscaler.net:9400
HTTPS_PROXY=http://username:password@gateway.zscaler.net:9400

# Or use separate credentials
PROXY_USER=your-username
PROXY_PASS=your-password
```

### Step 3: Configure Docker Desktop for Zscaler

1. Open **Docker Desktop**
2. Go to **Settings** → **Resources** → **Proxies**
3. Enable **Manual proxy configuration**
4. Enter your Zscaler settings:
   - **Web Server (HTTP)**: `http://gateway.zscaler.net:9400`
   - **Secure Web Server (HTTPS)**: `http://gateway.zscaler.net:9400`
5. Click **Apply & Restart**

### Step 4: Handle Zscaler SSL Inspection (If Enabled)

If your organization uses Zscaler SSL inspection, you need to install the Zscaler root certificate.

#### Check if SSL Inspection is Active

```bash
# Test SSL connection
curl -I https://www.google.com

# If you see certificate errors, SSL inspection is likely active
```

#### Install Zscaler Root Certificate

**Option A: System-wide Installation (Recommended)**

1. **Export Zscaler Root CA**:
   - Open Keychain Access
   - Search for "Zscaler"
   - Find "Zscaler Root CA" certificate
   - Right-click → Export → Save as `zscaler-root-ca.crt`

2. **Add to Docker**:
   ```bash
   # Create certificate directory
   mkdir -p ~/.docker/certs.d
   
   # Copy certificate
   cp ~/Downloads/zscaler-root-ca.crt ~/.docker/certs.d/
   
   # Restart Docker Desktop
   ```

**Option B: For Development Only (NOT for Production)**

```bash
# Disable SSL verification (INSECURE - dev only!)
export NODE_TLS_REJECT_UNAUTHORIZED=0
```

⚠️ **Warning**: Never use `NODE_TLS_REJECT_UNAUTHORIZED=0` in production!

### Step 5: Create Kind Cluster

```bash
# Create cluster with Zscaler proxy configuration
make create-cluster
```

The deployment script will:
1. Load Zscaler proxy settings from `proxy/proxy.env`
2. Configure containerd on all nodes
3. Configure kubelet on all nodes
4. Set environment variables

### Step 6: Verify Configuration

```bash
# Check proxy configuration on nodes
make check-containerd-proxy

# Test image pull
kubectl run test-nginx --image=nginx:latest --restart=Never

# Check pod status (should be Running)
kubectl get pod test-nginx

# Check events
kubectl describe pod test-nginx

# Clean up
kubectl delete pod test-nginx
```

## Zscaler-Specific Considerations

### 1. Authentication Methods

Zscaler supports multiple authentication methods:

**Machine-based Authentication (Most Common)**
- Uses device certificates
- No username/password needed in proxy settings
- Managed by Zscaler Client Connector

**User-based Authentication**
- Requires username/password
- Add credentials to `proxy/proxy.env`

**Cloud Connector**
- For cloud workloads
- May require different configuration

### 2. SSL Inspection

Zscaler can intercept and inspect SSL/TLS traffic:

**Indicators of SSL Inspection:**
- Certificate errors when accessing HTTPS sites
- Certificates issued by "Zscaler Root CA"
- HTTPS traffic visible in Zscaler logs

**Solutions:**
1. Install Zscaler root CA (recommended)
2. Add certificate to Docker trust store
3. Configure applications to trust Zscaler CA

### 3. PAC Files

Some Zscaler deployments use PAC (Proxy Auto-Configuration) files:

```bash
# Check for PAC file
scutil --proxy | grep ProxyAutoConfigURLString

# Download and inspect PAC file
curl -o zscaler.pac "$(scutil --proxy | grep ProxyAutoConfigURLString | awk '{print $3}')"
cat zscaler.pac
```

If using PAC files, extract the proxy server and port from the PAC file logic.

### 4. Bypass Lists

Zscaler may have predefined bypass lists. Ensure your `NO_PROXY` includes:
- Kubernetes cluster networks
- Docker networks
- Internal company domains
- localhost/127.0.0.1

## Troubleshooting

### Issue: Certificate Verification Failed

**Symptoms:**
```
x509: certificate signed by unknown authority
```

**Solutions:**

1. **Install Zscaler Root CA**:
   ```bash
   # Export from Keychain Access
   # Add to Docker and system trust store
   ```

2. **Verify certificate installation**:
   ```bash
   security find-certificate -a -c "Zscaler" -p
   ```

3. **For Docker containers**:
   ```bash
   # Add CA to container
   docker run --rm -v ~/.docker/certs.d:/etc/ssl/certs alpine cat /etc/ssl/certs/zscaler-root-ca.crt
   ```

### Issue: Connection Timeout

**Symptoms:**
```
dial tcp: i/o timeout
```

**Solutions:**

1. **Verify Zscaler is running**:
   ```bash
   # Check Zscaler Client Connector status
   ps aux | grep -i zscaler
   ```

2. **Check proxy settings**:
   ```bash
   scutil --proxy
   echo $HTTP_PROXY
   echo $HTTPS_PROXY
   ```

3. **Test proxy connectivity**:
   ```bash
   curl -I -x http://gateway.zscaler.net:9400 http://www.google.com
   ```

### Issue: Authentication Required (407)

**Symptoms:**
```
407 Proxy Authentication Required
```

**Solutions:**

1. **Add credentials to proxy.env**:
   ```bash
   PROXY_USER=your-username
   PROXY_PASS=your-password
   ```

2. **Or use inline authentication**:
   ```bash
   HTTP_PROXY=http://username:password@gateway.zscaler.net:9400
   ```

3. **Check if machine authentication is available**:
   - Ensure Zscaler Client Connector is running
   - Verify device is enrolled in Zscaler

### Issue: Images Won't Pull

**Symptoms:**
```
Failed to pull image: context deadline exceeded
```

**Solutions:**

1. **Check containerd proxy configuration**:
   ```bash
   make check-containerd-proxy
   ```

2. **Reconfigure proxy**:
   ```bash
   make configure-containerd-proxy
   ```

3. **Verify NO_PROXY settings**:
   ```bash
   # Ensure Docker networks are excluded
   NO_PROXY=localhost,127.0.0.*,172.17.*,...
   ```

4. **Check Docker Desktop proxy**:
   - Settings → Resources → Proxies
   - Ensure settings match proxy.env

### Issue: Zscaler App Conflicts

**Symptoms:**
- Proxy settings change automatically
- Inconsistent connectivity

**Solutions:**

1. **Use Zscaler-provided settings**:
   ```bash
   # Don't override Zscaler App settings
   # Use the gateway it provides
   ```

2. **Check Zscaler App configuration**:
   - Open Zscaler Client Connector
   - Verify gateway and authentication method

3. **Coordinate with IT**:
   - Some settings may be enforced by policy
   - Request exceptions if needed

## Testing Zscaler Configuration

### Test 1: Basic Connectivity

```bash
# Test HTTP through Zscaler
curl -I -x http://gateway.zscaler.net:9400 http://www.google.com

# Test HTTPS through Zscaler
curl -I -x http://gateway.zscaler.net:9400 https://www.google.com

# Expected: 200 OK or 301/302 redirect
```

### Test 2: Docker Registry Access

```bash
# Test Docker Hub access
curl -I -x http://gateway.zscaler.net:9400 https://registry-1.docker.io/v2/

# Expected: 401 Unauthorized (normal for Docker Hub)
```

### Test 3: From Docker Container

```bash
# Test from Alpine container
docker run --rm \
  -e http_proxy=http://gateway.zscaler.net:9400 \
  -e https_proxy=http://gateway.zscaler.net:9400 \
  alpine wget -O- http://www.google.com
```

### Test 4: Kind Cluster Image Pull

```bash
# Create cluster
make create-cluster

# Test image pull
kubectl run test-nginx --image=nginx:latest --restart=Never

# Wait and check
kubectl wait --for=condition=Ready pod/test-nginx --timeout=300s
kubectl get pod test-nginx

# Should show: STATUS=Running
```

## Advanced Configuration

### Using Zscaler with Private Registries

```bash
# Add private registry to NO_PROXY
NO_PROXY=localhost,127.0.0.1,172.17.*,registry.company.com

# Or configure registry-specific proxy
# In containerd config
```

### Zscaler with VPN

If using VPN alongside Zscaler:

```bash
# Add VPN networks to NO_PROXY
NO_PROXY=localhost,127.0.0.1,172.17.*,10.0.0.0/8,192.168.0.0/16

# Ensure VPN doesn't override proxy settings
```

### Monitoring Zscaler Traffic

```bash
# Check Zscaler logs (if available)
# Location varies by installation

# Monitor Docker container traffic
docker stats

# Check Kind node logs
make logs-paris
```

## Best Practices

1. **Use Machine Authentication**: Prefer device certificates over user credentials
2. **Install Root CA**: Always install Zscaler root CA for SSL inspection
3. **Keep Zscaler App Updated**: Ensure Zscaler Client Connector is current
4. **Document Your Gateway**: Save your specific gateway URL and port
5. **Test Before Deploying**: Verify proxy works before creating clusters
6. **Coordinate with IT**: Work with your IT team for proper configuration
7. **Use NO_PROXY Wisely**: Exclude internal networks to avoid unnecessary routing

## Environment-Specific Examples

### Example 1: Zscaler with Machine Auth (No Credentials)

```bash
# proxy/proxy.env
HTTP_PROXY=http://gateway.zscaler.net:9400
HTTPS_PROXY=http://gateway.zscaler.net:9400
NO_PROXY=localhost,127.0.0.1,127.0.0.*,172.17.*,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

### Example 2: Zscaler with User Authentication

```bash
# proxy/proxy.env
HTTP_PROXY=http://john.doe:SecurePass123@gateway.zscaler.net:9400
HTTPS_PROXY=http://john.doe:SecurePass123@gateway.zscaler.net:9400
NO_PROXY=localhost,127.0.0.1,127.0.0.*,172.17.*,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

### Example 3: Zscaler with Custom Gateway

```bash
# proxy/proxy.env
HTTP_PROXY=http://gateway.company.zscaler.net:80
HTTPS_PROXY=http://gateway.company.zscaler.net:80
NO_PROXY=localhost,127.0.0.1,127.0.0.*,172.17.*,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.company.com
```

## Quick Reference

```bash
# Auto-detect Zscaler settings (macOS)
make detect-zscaler

# Or manually find Zscaler gateway
scutil --proxy | grep HTTPProxy

# Test Zscaler connectivity
curl -I -x http://gateway.zscaler.net:9400 http://www.google.com

# Configure Kind
cp proxy/proxy.env.example proxy/proxy.env
vi proxy/proxy.env  # Add Zscaler settings
make create-cluster

# Verify
make check-containerd-proxy
kubectl run test --image=nginx --restart=Never
kubectl get pod test
```

## Additional Resources

- [Zscaler Documentation](https://help.zscaler.com/)
- [Zscaler Client Connector Guide](https://help.zscaler.com/z-app)
- [Docker Proxy Configuration](https://docs.docker.com/network/proxy/)
- [Kind Documentation](https://kind.sigs.k8s.io/)
- Main proxy documentation: [`proxy/README.md`](README.md)

## Support

If you encounter issues:

1. **Check Zscaler Status**: Ensure Zscaler Client Connector is running
2. **Verify Settings**: Use `scutil --proxy` to confirm gateway
3. **Test Connectivity**: Use curl to test proxy access
4. **Check Logs**: Review Docker and Kind logs for errors
5. **Contact IT**: Your IT team can provide Zscaler-specific settings
