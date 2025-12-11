kind create cluster --name zscaler --config kind-config.yaml


docker exec -it zscaler-control-plane ls -l /etc/ssl/certs/zscaler.pem

docker exec -it zscaler-control-plane bash
curl https://google.com
ping 8.8.8.8
dig google.com
nslookup google.com
traceroute google.com

docker exec -it zscaler-control-plane ctr --namespace k8s.io images pull docker.io/library/alpine:latest

