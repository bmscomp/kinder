# CNTLM Setup Guide for Kind with NTLM Proxy

This guide explains how to configure CNTLM in gateway mode to enable Kind clusters to work behind corporate proxies that require NTLM authentication.

## Overview

**Problem**: Corporate proxies using NTLM authentication don't work well with Docker/Kind because NTLM requires multiple round-trips that most tools don't support.

**Solution**: CNTLM (NTLM Authentication Proxy) runs on your host machine and handles NTLM authentication, providing a simple HTTP proxy interface that Docker/Kind can use.

## Architecture

```
Kind Cluster (172.17.0.x)
    ↓
Docker Bridge (172.17.0.1:3128)
    ↓
CNTLM on Host (Gateway Mode)
    ↓
Corporate NTLM Proxy
    ↓
Internet
```

## Prerequisites

- macOS or Linux host
- Corporate proxy requiring NTLM authentication
- Docker Desktop installed
- Admin/sudo access for CNTLM installation

## Installation

### macOS

```bash
# Install CNTLM via Homebrew
brew install cntlm
```

### Linux (Ubuntu/Debian)

```bash
# Install CNTLM
sudo apt-get update
sudo apt-get install cntlm
```

### Linux (RHEL/CentOS/Fedora)

```bash
# Install CNTLM
sudo yum install cntlm
# or
sudo dnf install cntlm
```

## Configuration

### Step 1: Find Your Docker Bridge IP

```bash
# On macOS
docker network inspect bridge | grep Gateway

# On Linux
ip addr show docker0 | grep "inet "

# Expected output (your IP may vary):
# macOS: "Gateway": "172.17.0.1"
# Linux: inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
```

**Note**: The Docker bridge IP is usually `172.17.0.1`. This is the IP where CNTLM will listen.

**Alternative method (works on both macOS and Linux):**
```bash
docker run --rm alpine ip route | grep default | awk '{print $3}'
# Output: 172.17.0.1
```

### Step 2: Generate CNTLM Password Hash

CNTLM needs your password in hashed format for security.

```bash
# Generate password hash (replace with your credentials)
cntlm -H -u YOUR_USERNAME -d YOUR_DOMAIN

# Example:
# cntlm -H -u john.doe -d CORP
```

When prompted, enter your password. CNTLM will output three hash types:

```
Password: 
PassLM          1234567890ABCDEF1234567890ABCDEF
PassNT          FEDCBA0987654321FEDCBA0987654321
PassNTLMv2      ABCD1234EFGH5678IJKL9012MNOP3456
```

**Save these hashes** - you'll need them in the next step.

### Step 3: Configure CNTLM

Edit the CNTLM configuration file:

**macOS**: `/usr/local/etc/cntlm.conf` or `/opt/homebrew/etc/cntlm.conf`
**Linux**: `/etc/cntlm.conf`

```bash
# macOS (Intel)
sudo nano /usr/local/etc/cntlm.conf

# macOS (Apple Silicon)
sudo nano /opt/homebrew/etc/cntlm.conf

# Linux
sudo nano /etc/cntlm.conf
```

**Configuration template**:

```ini
# Corporate proxy settings
Proxy           proxy.company.com:8080

# If you have multiple proxies, list them all
# Proxy         proxy2.company.com:8080

# Your corporate credentials
Username        YOUR_USERNAME
Domain          YOUR_DOMAIN

# Password hashes (from Step 2)
# Use the PassNTLMv2 hash for best security
PassNTLMv2      ABCD1234EFGH5678IJKL9012MNOP3456

# Alternative: Use PassNT if PassNTLMv2 doesn't work
# PassNT        FEDCBA0987654321FEDCBA0987654321

# IMPORTANT: Gateway mode - listen on all interfaces
# This allows Docker containers to connect
Gateway         yes
Listen          3128

# Optional: Specify which interfaces to listen on
# Listen        172.17.0.1:3128
# Listen        127.0.0.1:3128

# Domains that bypass the proxy
NoProxy         localhost, 127.0.0.*, 10.*, 172.16.*, 172.17.*, 192.168.*

# Authentication method (try NTLMv2 first, then NTLM)
Auth            NTLMv2
# Auth          NTLM

# Tunnel configuration for HTTPS
Tunnel          443:*:443
Tunnel          873:*:873
```

**Key settings explained**:

- **`Gateway yes`**: Critical! Allows containers to connect to CNTLM
- **`Listen 3128`**: Port where CNTLM listens (standard proxy port)
- **`NoProxy`**: Include Docker networks to avoid proxy loops
- **`Auth NTLMv2`**: Use NTLMv2 authentication (most secure)

### Step 4: Test CNTLM Configuration

Before starting the service, test the configuration:

```bash
# Test authentication (macOS Intel)
cntlm -c /usr/local/etc/cntlm.conf -I -M http://www.google.com

# Test authentication (macOS Apple Silicon)
cntlm -c /opt/homebrew/etc/cntlm.conf -I -M http://www.google.com

# Test authentication (Linux)
cntlm -c /etc/cntlm.conf -I -M http://www.google.com
```

**Expected output**:
```
Config profile  1/4... OK (HTTP code: 200)
----------------------------[ Profile  0 ]------
Auth            NTLMv2
PassNTLMv2      ABCD1234EFGH5678IJKL9012MNOP3456
------------------------------------------------
```

If you see "OK (HTTP code: 200)", authentication is working!

### Step 5: Start CNTLM Service

#### macOS

```bash
# Start CNTLM service
brew services start cntlm

# Check status
brew services list | grep cntlm

# View logs
tail -f /usr/local/var/log/cntlm.log
# or
tail -f /opt/homebrew/var/log/cntlm.log
```

#### Linux (systemd)

```bash
# Start CNTLM service
sudo systemctl start cntlm

# Enable on boot
sudo systemctl enable cntlm

# Check status
sudo systemctl status cntlm

# View logs
sudo journalctl -u cntlm -f
```

### Step 6: Verify CNTLM is Listening

```bash
# Check if CNTLM is listening on port 3128
netstat -an | grep 3128
# or
lsof -i :3128

# Expected output:
# tcp4  0  0  *.3128  *.*  LISTEN
```

### Step 7: Test Connectivity from Docker

```bash
# Test that Docker containers can reach CNTLM
docker run --rm alpine ping -c 2 172.17.0.1

# Test HTTP proxy through CNTLM
docker run --rm -e http_proxy=http://172.17.0.1:3128 alpine wget -O- http://www.google.com
```

If both commands succeed, CNTLM is working correctly!

## Configure Kind Cluster

### Step 1: Configure Proxy Environment

```bash
# Copy proxy configuration template
make configure-proxy

# Edit proxy/proxy.env
vi proxy/proxy.env
```

**Set these values in `proxy/proxy.env`**:

```bash
# Point to CNTLM on Docker bridge
HTTP_PROXY=http://172.17.0.1:3128
http_proxy=http://172.17.0.1:3128
HTTPS_PROXY=http://172.17.0.1:3128
https_proxy=http://172.17.0.1:3128

# Important: Include Docker bridge network in NO_PROXY
NO_PROXY=localhost,127.0.0.1,127.0.0.*,172.17.*,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16
no_proxy=localhost,127.0.0.1,127.0.0.*,172.17.*,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16
```

**Do NOT set** `PROXY_USER` or `PROXY_PASS` - CNTLM handles authentication!

### Step 2: Export Environment Variables

```bash
# Export proxy variables for the current session
export HTTP_PROXY=http://172.17.0.1:3128
export HTTPS_PROXY=http://172.17.0.1:3128
export NO_PROXY="localhost,127.0.0.*,172.17.*,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
export http_proxy=$HTTP_PROXY
export https_proxy=$HTTPS_PROXY
export no_proxy=$NO_PROXY
```

### Step 3: Create Kind Cluster

```bash
# Create cluster (proxy is auto-configured)
make create-cluster
```

The deployment script will:
1. Read proxy settings from `proxy/proxy.env`
2. Configure containerd on all nodes to use CNTLM
3. Configure kubelet to use CNTLM
4. Set environment variables in all nodes

### Step 4: Verify Cluster Can Pull Images

```bash
# Test image pull
kubectl run test-nginx --image=nginx:latest --restart=Never

# Check pod status (should be Running)
kubectl get pod test-nginx

# Check events (should show successful image pull)
kubectl describe pod test-nginx

# Clean up
kubectl delete pod test-nginx
```

## Troubleshooting

### CNTLM Not Starting

**Check configuration syntax**:
```bash
# macOS
cntlm -c /usr/local/etc/cntlm.conf -v

# Linux
cntlm -c /etc/cntlm.conf -v
```

**Check logs**:
```bash
# macOS
tail -f /usr/local/var/log/cntlm.log

# Linux
sudo journalctl -u cntlm -f
```

### Authentication Failures

**Try different auth methods** in `/etc/cntlm.conf`:
```ini
# Try these in order:
Auth    NTLMv2
# Auth  NTLM
# Auth  NT
```

**Regenerate password hash**:
```bash
cntlm -H -u YOUR_USERNAME -d YOUR_DOMAIN
```

### Containers Can't Reach CNTLM

**Verify Docker bridge IP**:
```bash
# On macOS
docker network inspect bridge | grep Gateway

# On Linux
ip addr show docker0 | grep "inet "

# Alternative (works on both)
docker run --rm alpine ip route | grep default | awk '{print $3}'
```

**Check firewall** (Linux):
```bash
# Allow traffic on port 3128
sudo iptables -I INPUT -p tcp --dport 3128 -j ACCEPT

# Or disable firewall temporarily for testing
sudo systemctl stop firewalld  # RHEL/CentOS
sudo ufw disable               # Ubuntu
```

**Test connectivity**:
```bash
# From host
curl -I -x http://172.17.0.1:3128 http://www.google.com

# From container
docker run --rm -e http_proxy=http://172.17.0.1:3128 alpine wget -O- http://www.google.com
```

### Image Pull Failures in Kind

**Check containerd proxy config**:
```bash
make check-containerd-proxy
```

**Reconfigure proxy**:
```bash
make configure-containerd-proxy
```

**Check CNTLM logs during image pull**:
```bash
# macOS
tail -f /usr/local/var/log/cntlm.log

# Linux
sudo journalctl -u cntlm -f
```

### NO_PROXY Issues

**Ensure Docker bridge is in NO_PROXY**:
```bash
# Must include 172.17.* to avoid proxy loops
NO_PROXY=localhost,127.0.0.*,172.17.*,...
```

**Test NO_PROXY**:
```bash
# Should NOT go through proxy
curl -v http://172.17.0.1:3128
```

## Advanced Configuration

### Multiple Corporate Proxies

If your company has multiple proxy servers:

```ini
# /etc/cntlm.conf
Proxy           proxy1.company.com:8080
Proxy           proxy2.company.com:8080
Proxy           proxy3.company.com:8080
```

CNTLM will try them in order until one succeeds.

### Custom Listen Address

To listen only on Docker bridge:

```ini
# /etc/cntlm.conf
Listen          172.17.0.1:3128
```

### Logging and Debugging

Enable verbose logging:

```ini
# /etc/cntlm.conf
Debug           1
```

View detailed logs:
```bash
# macOS
tail -f /usr/local/var/log/cntlm.log

# Linux
sudo journalctl -u cntlm -f
```

### Performance Tuning

For better performance with many connections:

```ini
# /etc/cntlm.conf
Threads         10
```

## Security Considerations

1. **Password Hashes**: Store password hashes, not plain text passwords
2. **File Permissions**: Restrict access to cntlm.conf
   ```bash
   sudo chmod 600 /etc/cntlm.conf
   sudo chown root:root /etc/cntlm.conf
   ```
3. **Gateway Mode**: Only enable if needed (required for Docker/Kind)
4. **Firewall**: Ensure only trusted networks can access port 3128

## Why This Works

### The Problem with NTLM

NTLM authentication requires:
1. Client sends request
2. Proxy responds with challenge
3. Client responds with credentials
4. Proxy authenticates and allows request

Most tools (including Docker) don't support this multi-step handshake.

### How CNTLM Solves It

1. **CNTLM handles NTLM**: Performs the complex NTLM handshake
2. **Simple interface**: Provides standard HTTP proxy to Docker/Kind
3. **Gateway mode**: Listens on Docker bridge so containers can connect
4. **Persistent connection**: Maintains authenticated connection to corporate proxy

### Why Export Variables

Even with CNTLM running, you must export `http_proxy` variables because:
- Docker daemon needs to know where the proxy is
- Kind needs to configure containerd with proxy settings
- Without exports, tools default to direct connection (which fails behind corporate proxy)

## Quick Reference

### Start/Stop CNTLM

```bash
# macOS
brew services start cntlm
brew services stop cntlm
brew services restart cntlm

# Linux
sudo systemctl start cntlm
sudo systemctl stop cntlm
sudo systemctl restart cntlm
```

### Check Status

```bash
# macOS
brew services list | grep cntlm

# Linux
sudo systemctl status cntlm
```

### Test Configuration

```bash
# Test auth
cntlm -c /etc/cntlm.conf -I -M http://www.google.com

# Test from container
docker run --rm -e http_proxy=http://172.17.0.1:3128 alpine wget -O- http://www.google.com
```

### Complete Setup Commands

```bash
# 1. Install CNTLM
brew install cntlm  # macOS
# or
sudo apt-get install cntlm  # Linux

# 2. Generate hash
cntlm -H -u YOUR_USERNAME -d YOUR_DOMAIN

# 3. Configure CNTLM (edit with your settings)
sudo nano /etc/cntlm.conf

# 4. Start CNTLM
brew services start cntlm  # macOS
# or
sudo systemctl start cntlm  # Linux

# 5. Export variables
export HTTP_PROXY=http://172.17.0.1:3128
export HTTPS_PROXY=$HTTP_PROXY
export NO_PROXY="localhost,127.0.0.*,172.17.*"
export http_proxy=$HTTP_PROXY
export https_proxy=$HTTPS_PROXY
export no_proxy=$NO_PROXY

# 6. Create Kind cluster
make create-cluster
```

## Additional Resources

- [CNTLM Official Documentation](http://cntlm.sourceforge.net/)
- [CNTLM GitHub](https://github.com/versat/cntlm)
- [Docker Proxy Configuration](https://docs.docker.com/network/proxy/)
- [Kind Proxy Documentation](https://kind.sigs.k8s.io/docs/user/configuration/#proxy)
