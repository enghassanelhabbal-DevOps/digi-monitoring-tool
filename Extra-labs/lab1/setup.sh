#!/bin/bash
# ============================================================
# Lab 1 Setup Script — Prometheus + Grafana on EC2
# Run this on a fresh Ubuntu 22.04 EC2 (t2.medium)
# ============================================================

set -e

echo "============================================"
echo "  Lab 1: Monitor EC2 with Prometheus+Grafana"
echo "============================================"

# ── Part A: Install Docker ───────────────────────────────────
echo ""
echo "Part A: Installing Docker..."
sudo apt update -y
sudo apt install -y docker.io docker-compose curl wget
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu
echo "✅ Docker installed"

# ── Part B: Install Node Exporter ───────────────────────────
echo ""
echo "Part B: Installing Node Exporter..."
NODE_EXPORTER_VERSION="1.8.2"
wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
sudo mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64*

# Install as systemd service
sudo cp node-exporter.service /etc/systemd/system/node_exporter.service
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

echo "✅ Node Exporter installed and running"
echo "   Test: curl http://localhost:9100/metrics | head -5"

# ── Part C: Start Prometheus + Grafana ──────────────────────
echo ""
echo "Part C: Starting Prometheus and Grafana..."
docker-compose up -d
echo "✅ Prometheus and Grafana started"

# ── Summary ─────────────────────────────────────────────────
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_EC2_IP")
echo ""
echo "============================================"
echo "  ✅ Setup Complete!"
echo "============================================"
echo "  Node Exporter: http://${PUBLIC_IP}:9100/metrics"
echo "  Prometheus UI: http://${PUBLIC_IP}:9090"
echo "  Grafana UI:    http://${PUBLIC_IP}:3000"
echo "  Grafana login: admin / admin123"
echo ""
echo "  Next step: Import Dashboard ID 1860 in Grafana"
echo "============================================"
