#!/bin/bash

# Zscaler Proxy Detection Script
# Automatically detects Zscaler proxy settings on macOS

set -e

echo "🔍 Detecting Zscaler proxy configuration..."
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  This script is designed for macOS"
    echo "   For other systems, check your network settings manually"
    exit 1
fi

# Function to extract proxy info
get_proxy_info() {
    scutil --proxy 2>/dev/null || echo ""
}

# Get proxy settings
PROXY_INFO=$(get_proxy_info)

if [[ -z "$PROXY_INFO" ]]; then
    echo "❌ Could not retrieve proxy settings"
    exit 1
fi

# Extract HTTP proxy
HTTP_PROXY_HOST=$(echo "$PROXY_INFO" | grep "HTTPProxy" | awk '{print $3}')
HTTP_PROXY_PORT=$(echo "$PROXY_INFO" | grep "HTTPPort" | awk '{print $3}')

# Extract HTTPS proxy
HTTPS_PROXY_HOST=$(echo "$PROXY_INFO" | grep "HTTPSProxy" | awk '{print $3}')
HTTPS_PROXY_PORT=$(echo "$PROXY_INFO" | grep "HTTPSPort" | awk '{print $3}')

# Check if Zscaler is detected
IS_ZSCALER=false
if [[ "$HTTP_PROXY_HOST" == *"zscaler"* ]] || [[ "$HTTPS_PROXY_HOST" == *"zscaler"* ]]; then
    IS_ZSCALER=true
fi

# Display results
echo "📊 Proxy Configuration Detected:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -n "$HTTP_PROXY_HOST" ]]; then
    echo "HTTP Proxy:  $HTTP_PROXY_HOST:$HTTP_PROXY_PORT"
else
    echo "HTTP Proxy:  Not configured"
fi

if [[ -n "$HTTPS_PROXY_HOST" ]]; then
    echo "HTTPS Proxy: $HTTPS_PROXY_HOST:$HTTPS_PROXY_PORT"
else
    echo "HTTPS Proxy: Not configured"
fi

echo ""

if [[ "$IS_ZSCALER" == true ]]; then
    echo "✅ Zscaler proxy detected!"
    echo ""
    echo "📝 Recommended Configuration:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Add to proxy/proxy.env:"
    echo ""
    echo "HTTP_PROXY=http://$HTTP_PROXY_HOST:$HTTP_PROXY_PORT"
    echo "http_proxy=http://$HTTP_PROXY_HOST:$HTTP_PROXY_PORT"
    echo "HTTPS_PROXY=http://$HTTPS_PROXY_HOST:$HTTPS_PROXY_PORT"
    echo "https_proxy=http://$HTTPS_PROXY_HOST:$HTTPS_PROXY_PORT"
    echo ""
    echo "NO_PROXY=localhost,127.0.0.1,127.0.0.*,172.17.*,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16"
    echo "no_proxy=localhost,127.0.0.1,127.0.0.*,172.17.*,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📖 Next Steps:"
    echo "   1. Copy configuration: cp proxy/proxy.env.example proxy/proxy.env"
    echo "   2. Edit proxy.env with the settings above"
    echo "   3. Configure Docker Desktop: Settings → Resources → Proxies"
    echo "   4. See proxy/ZSCALER_SETUP.md for SSL inspection setup"
    echo "   5. Create cluster: make create-cluster"
    echo ""
    
    # Check for Zscaler Client Connector
    if pgrep -x "Zscaler" > /dev/null; then
        echo "✅ Zscaler Client Connector is running"
    else
        echo "⚠️  Zscaler Client Connector may not be running"
        echo "   Check: Applications → Zscaler"
    fi
    
    # Check for Zscaler certificate
    echo ""
    echo "🔐 Checking for Zscaler Root CA certificate..."
    if security find-certificate -a -c "Zscaler" -p > /dev/null 2>&1; then
        echo "✅ Zscaler Root CA found in keychain"
        echo "   If SSL inspection is enabled, this certificate is installed"
    else
        echo "⚠️  Zscaler Root CA not found in keychain"
        echo "   If you encounter SSL errors, you may need to install it"
    fi
    
else
    echo "ℹ️  Generic proxy detected (not Zscaler)"
    echo ""
    if [[ -n "$HTTP_PROXY_HOST" ]]; then
        echo "📝 Recommended Configuration:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Add to proxy/proxy.env:"
        echo ""
        echo "HTTP_PROXY=http://$HTTP_PROXY_HOST:$HTTP_PROXY_PORT"
        echo "http_proxy=http://$HTTP_PROXY_HOST:$HTTP_PROXY_PORT"
        echo "HTTPS_PROXY=http://$HTTPS_PROXY_HOST:$HTTPS_PROXY_PORT"
        echo "https_proxy=http://$HTTPS_PROXY_HOST:$HTTPS_PROXY_PORT"
        echo ""
        echo "NO_PROXY=localhost,127.0.0.1,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
        echo "no_proxy=localhost,127.0.0.1,.local,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
        echo ""
    else
        echo "⚠️  No proxy configured in system settings"
        echo "   If you're behind a proxy, configure it manually in proxy/proxy.env"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Offer to test connectivity
if [[ -n "$HTTP_PROXY_HOST" ]]; then
    echo "🧪 Test proxy connectivity? (y/n)"
    read -r TEST_PROXY
    
    if [[ "$TEST_PROXY" == "y" || "$TEST_PROXY" == "Y" ]]; then
        echo ""
        echo "Testing HTTP connectivity..."
        if curl -I -x "http://$HTTP_PROXY_HOST:$HTTP_PROXY_PORT" http://www.google.com --connect-timeout 5 2>&1 | grep -q "200\|301\|302"; then
            echo "✅ HTTP proxy is working"
        else
            echo "❌ HTTP proxy test failed"
            echo "   This might be normal if authentication is required"
        fi
        
        echo ""
        echo "Testing HTTPS connectivity..."
        if curl -I -x "http://$HTTPS_PROXY_HOST:$HTTPS_PROXY_PORT" https://www.google.com --connect-timeout 5 2>&1 | grep -q "200\|301\|302"; then
            echo "✅ HTTPS proxy is working"
        else
            echo "⚠️  HTTPS proxy test failed"
            echo "   This might indicate SSL inspection or authentication requirements"
        fi
    fi
fi

echo ""
echo "✨ Detection complete!"
