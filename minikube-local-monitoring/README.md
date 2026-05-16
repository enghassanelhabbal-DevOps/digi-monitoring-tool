# 📊 Local Monitoring — Minikube with Prometheus & Grafana

> Run **Prometheus + Grafana locally in Docker** to monitor a **Minikube cluster** on your machine.

---

## 🏗️ Architecture

```
Your Local Machine (Mac / Linux)
│
├── Minikube Cluster (local Kubernetes)
│   └── node-exporter DaemonSet → :9100/metrics
│                │
│                │ scrape every 15s
│                ▼
├── Docker Containers
│   ├── Prometheus  → http://localhost:9090
│   └── Grafana     → http://localhost:3000
```

---

## 📁 Files

```
minikube-local-monitoring/
├── docker-compose.yml              ← Prometheus + Grafana
├── prometheus.yml                  ← Scrape config (set Minikube IP here)
├── node-exporter-daemonset.yaml    ← Deploy on Minikube
├── update-ip.sh                    ← Helper: auto-update Minikube IP
└── README.md
```

---

## ✅ Prerequisites

| Tool | Check |
|---|---|
| Docker | `docker --version` |
| Minikube | `minikube version` |
| kubectl | `kubectl version --client` |

---

## 🚀 Quick Start

```bash
# 1. Clone and enter folder
git clone https://github.com/YOUR_USERNAME/monitoring-labs.git
cd monitoring-labs/minikube-local-monitoring

# 2. Start Minikube
minikube start --driver=docker

# 3. Deploy Node Exporter on Minikube
kubectl apply -f node-exporter-daemonset.yaml

# 4. Get Minikube IP and update config
minikube ip
# Edit prometheus.yml → replace MINIKUBE_IP with the output

# 5. Start Prometheus + Grafana
docker-compose up -d

# 6. Open browser
# Prometheus: http://localhost:9090
# Grafana:    http://localhost:3000  (admin / admin123)
```

---

## 📋 Step-by-Step Lab

### Step 1 — Start Minikube

```bash
minikube start --driver=docker
```

Verify it's running:
```bash
kubectl get nodes
# NAME       STATUS   ROLES           AGE
# minikube   Ready    control-plane   1m
```

---

### Step 2 — Deploy Node Exporter on Minikube

```bash
kubectl apply -f node-exporter-daemonset.yaml
```

Wait for it to be Running:
```bash
kubectl get pods --watch
# node-exporter-xxx   1/1   Running   0   30s
```

Verify metrics are exposed:
```bash
curl http://$(minikube ip):9100/metrics | head -5
# Should show:
# # HELP node_cpu_seconds_total ...
# node_cpu_seconds_total{cpu="0",mode="idle"} 12345.6
```

> ✅ If you see metric lines — Node Exporter is working on Minikube!

---

### Step 3 — Update prometheus.yml with Minikube IP

Get your Minikube IP:
```bash
minikube ip
# example output: 192.168.49.2
```

Open `prometheus.yml` and replace `MINIKUBE_IP`:
```yaml
  - job_name: 'minikube-node'
    static_configs:
      - targets: ['192.168.49.2:9100']   # ← your actual IP here
```

Or use the helper script:
```bash
bash update-ip.sh
```

---

### Step 4 — Start Prometheus + Grafana

```bash
docker-compose up -d
```

Check containers are running:
```bash
docker-compose ps
# NAME         STATUS    PORTS
# prometheus   running   0.0.0.0:9090->9090/tcp
# grafana      running   0.0.0.0:3000->3000/tcp
```

---

### Step 5 — Verify Prometheus is Scraping Minikube

Open: **http://localhost:9090**

Go to: **Status → Targets**

```
minikube-node   http://192.168.49.2:9100/metrics   UP ✅
```

> ❌ If DOWN — see Troubleshooting section below.

---

### Step 6 — Setup Grafana

**Open:** http://localhost:3000
```
Username: admin
Password: admin123
```

**Add Prometheus Data Source:**
```
Home → Connections → Data Sources → Add → Prometheus
URL: http://prometheus:9090
→ Save & Test → Data source is working ✅
```

> ⚠️ Use `http://prometheus:9090` — NOT `localhost:9090`

**Import Dashboard:**
```
Home → Dashboards → Import
Dashboard ID: 1860 → Load
Select Prometheus → Import
```

> 🎉 You now see live Minikube node metrics — CPU, RAM, Disk, Network!

---

## 🔁 Every Time Minikube Restarts

Minikube IP can change after restart. Update it:

```bash
# Get new IP
minikube ip

# Update prometheus.yml manually OR run:
bash update-ip.sh

# Restart Prometheus to pick up new config
docker-compose restart prometheus
```

---

## 🔥 Generate Load to See Metrics Spike

```bash
# Run a CPU-heavy pod inside Minikube
kubectl run cpu-stress \
  --image=containerstack/alpine-stress \
  --restart=Never \
  -- stress --cpu 2 --timeout 60s

# Watch pod
kubectl get pods --watch

# Watch CPU spike in Grafana ↑
# Set dashboard refresh to 5s

# Clean up
kubectl delete pod cpu-stress
```

---

## 🔍 Useful PromQL Queries

Test in Prometheus UI → **Graph** tab:

```promql
# Minikube node CPU usage %
100 - (avg(rate(node_cpu_seconds_total{mode="idle",instance="minikube"}[5m])) * 100)

# RAM available in GB
node_memory_MemAvailable_bytes{instance="minikube"} / 1024 / 1024 / 1024

# Check if Minikube node is up
up{job="minikube-node"}

# Disk usage %
100 - (node_filesystem_avail_bytes{mountpoint="/"} * 100 / node_filesystem_size_bytes{mountpoint="/"})
```

---

## 🛑 Manage the Stack

```bash
# Start
docker-compose up -d

# Stop (keeps data)
docker-compose down

# Stop and delete all data
docker-compose down -v

# Restart Prometheus (after editing prometheus.yml)
docker-compose restart prometheus

# View logs
docker-compose logs -f prometheus
docker-compose logs -f grafana
```

---

## 🐛 Troubleshooting

### Target shows DOWN in Prometheus

**Check 1 — Minikube IP changed:**
```bash
minikube ip
# compare with what's in prometheus.yml
```

**Check 2 — Node Exporter running in Minikube:**
```bash
kubectl get pods | grep node-exporter
# must show Running
```

**Check 3 — Reachable from your Mac:**
```bash
curl http://$(minikube ip):9100/metrics | head -3
# if this fails → networking issue
```

**Fix for Mac — use minikube tunnel:**
```bash
# Terminal 1 — keep this running
minikube tunnel

# Then update prometheus.yml target to:
# targets: ['127.0.0.1:9100']
docker-compose restart prometheus
```

---

### Grafana: No Data in Dashboard

1. Check Prometheus Target is **UP**: http://localhost:9090/targets
2. Change time range to **Last 15 minutes**
3. Make sure Data Source URL is `http://prometheus:9090`

---

### Node Exporter Pod in Pending or CrashLoopBackOff

```bash
# Check why
kubectl describe pod -l app=node-exporter

# Delete and redeploy
kubectl delete -f node-exporter-daemonset.yaml
kubectl apply -f node-exporter-daemonset.yaml
```

---

## 📊 Ports Reference

| Service | Port | Access |
|---|---|---|
| Node Exporter (Minikube) | 9100 | `http://$(minikube ip):9100` |
| Prometheus (local Docker) | 9090 | `http://localhost:9090` |
| Grafana (local Docker) | 3000 | `http://localhost:3000` |

---

## 🎓 DevOps Scholarship — Monitoring Track
