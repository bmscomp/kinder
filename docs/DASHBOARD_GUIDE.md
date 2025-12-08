# Kubernetes Dashboard Guide

Complete guide for deploying and using the Kubernetes Dashboard in your Kind cluster.

## Overview

The Kubernetes Dashboard is a web-based UI for managing and monitoring your Kubernetes cluster. It provides:
- Visual overview of cluster resources
- Resource monitoring and metrics
- Log viewing and debugging
- Workload management
- RBAC and security management

## Quick Start

### 1. Deploy Dashboard

```bash
make deploy-dashboard
```

**What this does:**
- Deploys Kubernetes Dashboard v2.7.0
- Creates `kubernetes-dashboard` namespace
- Creates admin service account with cluster-admin privileges
- Generates access token and saves to `dashboard-token.txt`

**Expected output:**
```
=== Kubernetes Dashboard Deployment ===

[INFO] Checking if cluster is running...
[INFO] Cluster is running ✓
[INFO] Deploying Kubernetes Dashboard v2.7.0...
[INFO] Waiting for dashboard pods to be ready...
[SUCCESS] Dashboard deployed successfully ✓
[INFO] Creating admin service account...
[INFO] Service account created ✓
[INFO] Creating cluster role binding...
[INFO] Cluster role binding created ✓
[INFO] Creating token secret...
[INFO] Token secret created ✓
[INFO] Retrieving access token...

========================================
Dashboard Access Token:
========================================
eyJhbGciOiJSUzI1NiIsImtpZCI6IjBhZ...
========================================

[SUCCESS] Access token retrieved ✓
[INFO] Token saved to: dashboard-token.txt
```

### 2. Start Proxy

```bash
make dashboard-proxy
```

This starts `kubectl proxy` which creates a secure tunnel to the cluster. Keep this terminal running.

### 3. Access Dashboard

Open your browser and navigate to:
```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

### 4. Login

When prompted, select **Token** authentication and paste the token from:
```bash
make dashboard-token
```

## Makefile Commands

| Command | Description |
|---------|-------------|
| `make deploy-dashboard` | Deploy dashboard to cluster |
| `make delete-dashboard` | Remove dashboard from cluster |
| `make dashboard-proxy` | Start kubectl proxy (required for access) |
| `make dashboard-token` | Display access token |
| `make dashboard-url` | Display dashboard URL |

## Detailed Usage

### Deploying Dashboard

The deployment script performs the following steps:

1. **Checks cluster availability**
   ```bash
   kubectl cluster-info
   ```

2. **Deploys dashboard manifest**
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
   ```

3. **Creates admin service account**
   - Service account: `admin-user`
   - Namespace: `kubernetes-dashboard`
   - Role: `cluster-admin`

4. **Generates access token**
   - Creates a long-lived token secret
   - Saves token to `dashboard-token.txt`

### Accessing Dashboard

#### Method 1: Using Makefile (Recommended)

```bash
# Terminal 1: Start proxy
make dashboard-proxy

# Terminal 2: Get token
make dashboard-token

# Open browser to the URL shown by dashboard-proxy
```

#### Method 2: Manual Access

```bash
# Terminal 1: Start proxy
kubectl proxy

# Terminal 2: Get token
kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 --decode

# Open browser
open "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
```

### Dashboard Features

Once logged in, you can:

#### 1. View Cluster Overview
- **Workloads**: Deployments, ReplicaSets, Pods, Jobs, CronJobs
- **Discovery**: Services, Ingresses
- **Config**: ConfigMaps, Secrets
- **Storage**: PersistentVolumes, PersistentVolumeClaims, StorageClasses

#### 2. Monitor Resources
- CPU and memory usage per pod
- Node resource utilization
- Pod status and health

#### 3. View Logs
- Real-time pod logs
- Container logs
- Event logs

#### 4. Execute Commands
- Open shell in containers
- Execute commands directly from UI

#### 5. Manage Workloads
- Scale deployments
- Edit resource definitions
- Delete resources

## Common Tasks

### View All Pods

1. Navigate to **Workloads** → **Pods**
2. Select **All namespaces** from dropdown
3. View pod status, age, and resource usage

### Check Pod Logs

1. Navigate to **Workloads** → **Pods**
2. Click on a pod name
3. Click **Logs** icon in the top right
4. View real-time logs

### Scale a Deployment

1. Navigate to **Workloads** → **Deployments**
2. Click on deployment name
3. Click **Scale** icon
4. Enter desired replica count

### Execute Shell in Pod

1. Navigate to **Workloads** → **Pods**
2. Click on a pod name
3. Click **Exec** icon
4. Select container (if multiple)
5. Execute commands in the shell

### View Cluster Nodes

1. Navigate to **Cluster** → **Nodes**
2. View node status, capacity, and allocatable resources
3. Click node name for detailed metrics

## Security Considerations

### Admin Access

The default deployment creates a service account with **cluster-admin** privileges, which provides full access to the cluster.

**For production environments**, consider:

1. **Creating limited-access accounts**
   ```bash
   # Create read-only service account
   kubectl create serviceaccount dashboard-viewer -n kubernetes-dashboard
   kubectl create clusterrolebinding dashboard-viewer \
     --clusterrole=view \
     --serviceaccount=kubernetes-dashboard:dashboard-viewer
   ```

2. **Using namespace-specific roles**
   ```bash
   # Create namespace-specific admin
   kubectl create serviceaccount app-admin -n my-app
   kubectl create rolebinding app-admin \
     --clusterrole=admin \
     --serviceaccount=my-app:app-admin \
     --namespace=my-app
   ```

### Token Management

- **Token location**: `dashboard-token.txt` (git-ignored)
- **Token type**: Long-lived service account token
- **Rotation**: Delete and recreate service account to rotate token

**To rotate token:**
```bash
# Delete dashboard
make delete-dashboard

# Redeploy (generates new token)
make deploy-dashboard
```

### Network Security

- Dashboard is only accessible via `kubectl proxy`
- Proxy creates secure tunnel using kubeconfig credentials
- No direct external access to dashboard
- Suitable for local development

## Troubleshooting

### Dashboard Pods Not Running

Check pod status:
```bash
kubectl get pods -n kubernetes-dashboard
kubectl describe pod <pod-name> -n kubernetes-dashboard
```

Common issues:
- Image pull errors (check proxy configuration)
- Resource constraints (check node resources)

### Cannot Access Dashboard URL

**Issue**: Browser shows "connection refused"

**Solution**:
1. Ensure proxy is running: `make dashboard-proxy`
2. Check proxy output for errors
3. Verify URL is correct: `make dashboard-url`

### Token Authentication Fails

**Issue**: "Invalid token" error

**Solution**:
1. Get fresh token: `make dashboard-token`
2. Copy entire token (no spaces or newlines)
3. If still fails, redeploy dashboard: `make delete-dashboard && make deploy-dashboard`

### Dashboard Shows Empty/No Resources

**Issue**: Dashboard loads but shows no resources

**Possible causes**:
1. **Wrong namespace selected**: Select "All namespaces" from dropdown
2. **RBAC permissions**: Verify service account has correct permissions
3. **Cluster issues**: Check cluster status with `kubectl get nodes`

### Proxy Connection Issues

**Issue**: Proxy fails to start

**Solution**:
```bash
# Check if another proxy is running
ps aux | grep "kubectl proxy"

# Kill existing proxy
pkill -f "kubectl proxy"

# Restart proxy
make dashboard-proxy
```

## Advanced Configuration

### Custom Dashboard Version

Edit `scripts/deploy-dashboard.sh`:
```bash
DASHBOARD_VERSION="v2.7.0"  # Change to desired version
```

### Custom Service Account Name

Edit `scripts/deploy-dashboard.sh`:
```bash
SERVICE_ACCOUNT_NAME="admin-user"  # Change to desired name
```

### Custom Namespace

Edit `scripts/deploy-dashboard.sh`:
```bash
DASHBOARD_NAMESPACE="kubernetes-dashboard"  # Change to desired namespace
```

### Expose Dashboard via NodePort (Not Recommended)

For testing purposes only:
```bash
kubectl patch svc kubernetes-dashboard -n kubernetes-dashboard -p '{"spec":{"type":"NodePort"}}'
kubectl get svc kubernetes-dashboard -n kubernetes-dashboard
```

**Warning**: This exposes the dashboard externally. Use only in isolated development environments.

## Integration with Proxy

If your cluster is behind a corporate proxy, the dashboard will automatically use the proxy configuration for pulling images.

Verify dashboard pods can pull images:
```bash
kubectl describe pod -n kubernetes-dashboard | grep -i image
```

If image pull fails:
1. Verify proxy configuration: `make check-containerd-proxy`
2. Reconfigure proxy: `make configure-containerd-proxy`
3. Delete and redeploy dashboard: `make delete-dashboard && make deploy-dashboard`

## Cleanup

### Delete Dashboard

```bash
make delete-dashboard
```

This removes:
- Dashboard namespace and all resources
- Admin service account
- Cluster role binding
- Token file (`dashboard-token.txt`)

### Verify Deletion

```bash
kubectl get namespace kubernetes-dashboard
# Should show: Error from server (NotFound)

kubectl get clusterrolebinding admin-user
# Should show: Error from server (NotFound)
```

## Best Practices

1. **Keep proxy running**: Don't close the terminal running `kubectl proxy`
2. **Secure token**: Don't share your access token
3. **Use namespaces**: Organize resources in namespaces for better management
4. **Monitor resources**: Regularly check resource usage in dashboard
5. **Review logs**: Use dashboard to quickly access pod logs
6. **Limit access**: In production, use role-based access control

## Additional Resources

- [Kubernetes Dashboard Documentation](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)
- [Dashboard GitHub Repository](https://github.com/kubernetes/dashboard)
- [RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

## Quick Reference

```bash
# Deploy
make deploy-dashboard

# Access (in separate terminals)
make dashboard-proxy    # Terminal 1
make dashboard-token    # Terminal 2 - copy token
# Open browser to URL

# Manage
make dashboard-url      # Show URL
make dashboard-token    # Show token
make delete-dashboard   # Remove dashboard

# Troubleshoot
kubectl get pods -n kubernetes-dashboard
kubectl logs -n kubernetes-dashboard <pod-name>
kubectl describe pod -n kubernetes-dashboard <pod-name>
```
