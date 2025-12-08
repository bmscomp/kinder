# Kubernetes Dashboard - Quick Start

Get the Kubernetes Dashboard up and running in 3 minutes.

## Prerequisites

- Cluster must be running: `make create-cluster`
- kubectl configured to access the cluster

## 3-Step Setup

### Step 1: Deploy Dashboard

```bash
make deploy-dashboard
```

Wait for deployment to complete (~1-2 minutes). You'll see:
```
=== Dashboard Deployment Complete ===
```

### Step 2: Start Proxy

Open a new terminal and run:
```bash
make dashboard-proxy
```

**Keep this terminal running!**

### Step 3: Access Dashboard

1. **Open browser** to:
   ```
   http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
   ```

2. **Get your token** (in another terminal):
   ```bash
   make dashboard-token
   ```

3. **Copy the token** and paste it into the dashboard login page

4. **Click "Sign in"**

## You're Done! 🎉

You should now see the Kubernetes Dashboard with full cluster access.

## Quick Commands

```bash
# View token again
make dashboard-token

# Get dashboard URL
make dashboard-url

# Stop proxy (Ctrl+C in proxy terminal)

# Remove dashboard
make delete-dashboard
```

## What Can I Do Now?

### View Your Cluster
- Navigate to **Cluster** → **Nodes** to see paris, berlin, london
- Check **Workloads** → **Pods** to see all running pods
- View **Config and Storage** → **ConfigMaps** and **Secrets**

### Deploy an Application
1. Click **+** (Create) in top right
2. Choose "Create from form" or "Create from YAML"
3. Deploy a sample nginx:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: nginx
   spec:
     replicas: 2
     selector:
       matchLabels:
         app: nginx
     template:
       metadata:
         labels:
           app: nginx
       spec:
         containers:
         - name: nginx
           image: nginx:latest
           ports:
           - containerPort: 80
   ```

### View Logs
1. Go to **Workloads** → **Pods**
2. Click on any pod
3. Click the **Logs** icon (📄) in top right

### Execute Shell
1. Go to **Workloads** → **Pods**
2. Click on any pod
3. Click the **Exec** icon (>_) in top right

## Troubleshooting

### "Connection refused" error
- Make sure proxy is running: `make dashboard-proxy`
- Check the URL is correct: `make dashboard-url`

### "Invalid token" error
- Get fresh token: `make dashboard-token`
- Copy the entire token (no extra spaces)

### Dashboard shows no resources
- Select **All namespaces** from the dropdown at the top

## Next Steps

For detailed information, see:
- **Full guide**: `DASHBOARD_GUIDE.md`
- **Main docs**: `README.md`

## One-Liner Cheat Sheet

```bash
# Deploy and get token
make deploy-dashboard && make dashboard-token

# In another terminal: start proxy
make dashboard-proxy

# Open browser to:
# http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```
