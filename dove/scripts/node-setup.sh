#!/bin/sh
apt-get update
apt-get install -y \
  curl \
  iputils-ping \
  dnsutils \
  net-tools \
  traceroute
