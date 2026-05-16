#!/bin/bash
# ============================================================
# update-ip.sh
# Automatically updates prometheus.yml with current Minikube IP
# Run this every time Minikube restarts (IP may change)
# ============================================================

MINIKUBE_IP=$(minikube ip)

if [ -z "$MINIKUBE_IP" ]; then
  echo "❌ Could not get Minikube IP. Is Minikube running?"
  echo "   Run: minikube start"
  exit 1
fi

echo "Minikube IP: $MINIKUBE_IP"

# Update prometheus.yml
sed -i.bak "s/MINIKUBE_IP/$MINIKUBE_IP/g" prometheus.yml
sed -i.bak "s/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:9100/$MINIKUBE_IP:9100/g" prometheus.yml

echo "✅ prometheus.yml updated with IP: $MINIKUBE_IP"
echo ""
echo "Now run: docker-compose restart prometheus"
