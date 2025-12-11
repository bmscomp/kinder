#!/bin/bash

# Force apt to use the correct proxy
echo 'Acquire::http::Proxy "http://host.docker.internal:9000";'  > /etc/apt/apt.conf.d/99proxy
echo 'Acquire::https::Proxy "http://host.docker.internal:9000";' >> /etc/apt/apt.conf.d/99proxy

apt-get update
apt-get install -y \
  curl \
  iputils-ping \
  dnsutils \
  net-tools \
  traceroute
