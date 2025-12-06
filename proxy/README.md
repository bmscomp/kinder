# Proxy Configuration

This directory contains proxy configuration files for running Kind behind a corporate proxy.

## Setup

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

## Security Notes

- **Never commit `proxy/proxy.env` to version control** (it's in .gitignore)
- Store credentials securely
- Consider using environment variables instead of storing passwords in files
- Rotate credentials regularly

## Files

- `proxy.env.example` - Template configuration file
- `proxy.env` - Your actual configuration (git-ignored)
- `README.md` - This documentation
