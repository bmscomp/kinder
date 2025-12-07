# Proxy Configuration

This directory contains proxy configuration files for running Kind behind a corporate proxy.

## Setup

### Option 1: Direct Proxy (Basic/Digest Authentication)

1. Copy the example configuration:
   ```bash
   cp proxy/proxy.env.example proxy/proxy.env
   ```

2. Edit `proxy/proxy.env` with your corporate proxy settings:
   ```bash
   HTTP_PROXY=http://your-proxy.company.com:8080
   HTTPS_PROXY=http://your-proxy.company.com:8080
   NO_PROXY=localhost,127.0.0.1,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
   ```

3. If your proxy requires authentication, add:
   ```bash
   PROXY_USER=your-username
   PROXY_PASS=your-password
   ```

### Option 2: CNTLM Gateway Mode (NTLM Authentication)

**For corporate proxies requiring NTLM authentication**, use CNTLM:

1. **Install and configure CNTLM** (see [`CNTLM_SETUP.md`](CNTLM_SETUP.md) for detailed guide)

2. **Find your Docker bridge IP**:
   ```bash
   ip addr show docker0 | grep "inet "
   # Usually: 172.17.0.1
   ```

3. **Configure proxy.env** to point to CNTLM:
   ```bash
   cp proxy/proxy.env.example proxy/proxy.env
   vi proxy/proxy.env
   ```

   Set these values:
   ```bash
   HTTP_PROXY=http://172.17.0.1:3128
   HTTPS_PROXY=http://172.17.0.1:3128
   NO_PROXY=localhost,127.0.0.1,127.0.0.*,172.17.*,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
   ```

4. **Export environment variables**:
   ```bash
   export HTTP_PROXY=http://172.17.0.1:3128
   export HTTPS_PROXY=$HTTP_PROXY
   export NO_PROXY="localhost,127.0.0.*,172.17.*,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
   export http_proxy=$HTTP_PROXY
   export https_proxy=$HTTPS_PROXY
   export no_proxy=$NO_PROXY
   ```

5. **Create cluster**:
   ```bash
   make create-cluster
   ```

> **📖 Full CNTLM Guide**: See [`CNTLM_SETUP.md`](CNTLM_SETUP.md) for complete setup instructions

## What Gets Configured

The deployment script will configure proxy settings at multiple levels:

### 1. Host Environment
- Exports proxy environment variables for the deployment script

### 2. Docker Daemon (macOS)
- **Important**: On macOS with Docker Desktop, you must also configure proxy in:
  - Docker Desktop → Settings → Resources → Proxies
  - Enable "Manual proxy configuration"
  - Enter your HTTP/HTTPS proxy URLs

### 3. Kind Node Containers
- Configures containerd with proxy settings
- Configures kubelet with proxy settings
- Ensures Kubernetes can pull images through the proxy

### 4. Docker Registry Mirror (Optional)
- Can be configured in `config/kind-cluster-config.yaml`

## Makefile Commands for Containerd Proxy

After cluster creation, you can manage containerd proxy configuration using these commands:

### Configure Containerd Proxy on All Nodes
```bash
make configure-containerd-proxy
```
This command:
- Reads settings from `proxy/proxy.env`
- Configures containerd proxy on all nodes (paris, berlin, london)
- Configures kubelet proxy on all nodes
- Sets environment variables in `/etc/environment`
- Automatically restarts containerd to apply changes

### Check Containerd Proxy Configuration
```bash
make check-containerd-proxy
```
This command displays:
- Containerd proxy configuration from `/etc/systemd/system/containerd.service.d/http-proxy.conf`
- Kubelet proxy configuration from `/etc/systemd/system/kubelet.service.d/http-proxy.conf`
- Environment variables from `/etc/environment`
- Status for all three nodes

### Restart Containerd Service
```bash
make restart-containerd
```
This command:
- Reloads systemd daemon on all nodes
- Restarts containerd service on all nodes
- Useful after manually modifying proxy configuration

## Testing Proxy Configuration

After cluster creation, verify proxy is working:

```bash
# Check if nodes can pull images
kubectl run test-nginx --image=nginx:latest --restart=Never

# Check pod status
kubectl get pods test-nginx

# If successful, the image was pulled through the proxy
kubectl describe pod test-nginx

# Clean up
kubectl delete pod test-nginx
```

## Troubleshooting

### Images Not Pulling

1. Verify proxy settings in `proxy/proxy.env`
2. Check Docker Desktop proxy configuration (macOS)
3. Verify NO_PROXY includes cluster networks
4. Check containerd proxy configuration:
   ```bash
   make shell-paris
   cat /etc/systemd/system/containerd.service.d/http-proxy.conf
   ```

### Authentication Issues

If your proxy requires authentication:
- Ensure PROXY_USER and PROXY_PASS are set
- The script will construct authenticated URLs automatically
- Format: `http://username:password@proxy.company.com:8080`

### SSL/TLS Issues

If you encounter SSL certificate issues:
- Your proxy might be intercepting SSL traffic
- You may need to add your corporate CA certificate
- Contact your IT department for the CA certificate

### CNTLM Issues

If using CNTLM and images still won't pull:

1. **Verify CNTLM is running**:
   ```bash
   # macOS
   brew services list | grep cntlm
   
   # Linux
   sudo systemctl status cntlm
   ```

2. **Check CNTLM is listening**:
   ```bash
   netstat -an | grep 3128
   # Should show: tcp4  0  0  *.3128  *.*  LISTEN
   ```

3. **Test connectivity from container**:
   ```bash
   docker run --rm alpine ping -c 2 172.17.0.1
   docker run --rm -e http_proxy=http://172.17.0.1:3128 alpine wget -O- http://www.google.com
   ```

4. **Verify Docker bridge IP**:
   ```bash
   ip addr show docker0 | grep "inet "
   # Update proxy.env if IP is different from 172.17.0.1
   ```

5. **Check CNTLM logs**:
   ```bash
   # macOS
   tail -f /usr/local/var/log/cntlm.log
   
   # Linux
   sudo journalctl -u cntlm -f
   ```

6. **Ensure Gateway mode is enabled** in `/etc/cntlm.conf`:
   ```ini
   Gateway    yes
   Listen     3128
   ```

7. **Verify NO_PROXY includes Docker bridge**:
   ```bash
   # Must include 172.17.* to avoid proxy loops
   NO_PROXY=localhost,127.0.0.*,172.17.*,...
   ```

For detailed CNTLM troubleshooting, see [`CNTLM_SETUP.md`](CNTLM_SETUP.md).

## Security Notes

- **Never commit `proxy/proxy.env` to version control** (it's in .gitignore)
- Store credentials securely
- Consider using environment variables instead of storing passwords in files
- Rotate credentials regularly

## Files

- `proxy.env.example` - Template configuration file (includes CNTLM example)
- `proxy.env` - Your actual configuration (git-ignored)
- `README.md` - This documentation
- `CNTLM_SETUP.md` - Complete CNTLM setup guide for NTLM proxies
