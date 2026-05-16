# 📊 Local Monitoring — Remote EC2

> Run Prometheus + Grafana on your **local machine** to monitor a **remote EC2** on AWS.

---

## 🏗️ Architecture

```
Your Local Machine (Mac / Linux / Windows)
├── Docker
│   ├── Prometheus  → http://localhost:9090
│   └── Grafana     → http://localhost:3000
│           │
│           │  scrapes every 15s over internet
│           ▼
Remote EC2 on AWS
└── Node Exporter   → :9100/metrics  (only this runs on EC2)
```

**The idea:**
- EC2 only runs **Node Exporter** — lightweight, no Docker needed
- Prometheus and Grafana run **on your local machine** in Docker
- Prometheus reaches EC2 over the internet via Public IP

---

## 📁 Files

```
.
├── prometheus.yml        ← Prometheus scrape config (edit EC2 IP here)
├── docker-compose.yml    ← Runs Prometheus + Grafana locally
└── README.md
```

---

## ✅ Prerequisites

| Where | What |
|---|---|
| Local machine | Docker installed and running |
| AWS EC2 | Ubuntu 22.04, any size (t2.micro is enough) |
| AWS Security Group | Port **22** (SSH) and **9100** (Node Exporter) open |

---

## 🖥️ Step 1 — Setup EC2 (Node Exporter only)

### 1.1 Open port 9100 in Security Group

```
AWS Console → EC2 → your instance
→ Security → Security Groups → Edit Inbound Rules
→ Add Rule:
    Type: Custom TCP
    Port: 9100
    Source: 0.0.0.0/0
→ Save
```

### 1.2 SSH into EC2

```bash
ssh -i your-key.pem ubuntu@EC2_PUBLIC_IP
```

### 1.3 Install Node Exporter

```bash
# Download
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz

# Extract and install
tar xvf node_exporter-1.8.2.linux-amd64.tar.gz
sudo mv node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-1.8.2.linux-amd64*
```

### 1.4 Run as systemd service (starts on reboot)

```bash
sudo tee /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=ubuntu
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
```

### 1.5 Verify Node Exporter is working

```bash
curl http://localhost:9100/metrics | head -5
```

You should see lines like:
```
# HELP node_cpu_seconds_total ...
node_cpu_seconds_total{cpu="0",mode="idle"} 12345.6
```

### 1.6 Test from your local machine

```bash
curl http://EC2_PUBLIC_IP:9100/metrics | head -5
```

> ✅ If you see metric lines from your local machine — Node Exporter is reachable!

---

## 💻 Step 2 — Setup Local Machine

### 2.1 Clone this repo

```bash
git clone https://github.com/YOUR_USERNAME/monitoring-labs.git
cd monitoring-labs/local-monitoring
```

### 2.2 Edit prometheus.yml — add your EC2 IP

Open `prometheus.yml` and replace `EC2_PUBLIC_IP`:

```yaml
scrape_configs:
  - job_name: 'ec2-node'
    static_configs:
      - targets: ['EC2_PUBLIC_IP:9100']   # ← replace this
```

Example:
```yaml
      - targets: ['54.123.45.67:9100']
```

### 2.3 Start Prometheus + Grafana

```bash
docker-compose up -d
```

### 2.4 Verify containers are running

```bash
docker-compose ps
```

Expected output:
```
NAME         STATUS    PORTS
prometheus   running   0.0.0.0:9090->9090/tcp
grafana      running   0.0.0.0:3000->3000/tcp
```

---

## 🔥 Step 3 — Check Prometheus is Scraping EC2

Open in browser:
```
http://localhost:9090
```

Go to: **Status → Targets**

You should see:

```
ec2-node    http://54.123.45.67:9100/metrics    UP    ✅
```

> ❌ If it shows DOWN — check the EC2 IP in `prometheus.yml` and port 9100 in Security Group.

---

## 📊 Step 4 — Setup Grafana

### 4.1 Open Grafana

```
http://localhost:3000
Username: admin
Password: admin123
```

### 4.2 Add Prometheus as Data Source

```
Home → Connections → Data Sources → Add
→ Select: Prometheus
→ URL: http://prometheus:9090
→ Click: Save & Test
→ Should show: Data source is working ✅
```

> ⚠️ Use `http://prometheus:9090` — NOT `localhost:9090`.
> Both containers are in the same Docker network and talk by container name.

### 4.3 Import Dashboard 1860

```
Home → Dashboards → Import
→ Dashboard ID: 1860
→ Load
→ Select Prometheus data source
→ Import
```

> 🎉 You now have a live dashboard showing your EC2 CPU, RAM, Disk, Network!

---

## 📈 What You Can Monitor

| Metric | Description |
|---|---|
| **CPU Usage %** | Per core and total — user, system, iowait |
| **Memory** | Total, used, free, cached, available |
| **Disk I/O** | Read/write MB/s, utilization % |
| **Network** | Bytes in/out per second |
| **System Load** | 1min, 5min, 15min load average |
| **Uptime** | How long EC2 has been running |

---

## 🔍 Useful PromQL Queries

Test these in Prometheus UI → Graph tab:

```promql
# CPU usage percentage
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Available RAM in GB
node_memory_MemAvailable_bytes / 1024 / 1024 / 1024

# Disk usage percentage
100 - (node_filesystem_avail_bytes * 100 / node_filesystem_size_bytes)

# Network receive rate (bytes/sec)
rate(node_network_receive_bytes_total{device="eth0"}[5m])

# Check if EC2 is up
up{job="ec2-node"}
```

---

## 🛑 Stop / Start

```bash
# Stop
docker-compose down

# Start again
docker-compose up -d

# Stop and delete data
docker-compose down -v
```

---

## 🐛 Troubleshooting

### Target shows DOWN in Prometheus

```
Status → Targets → ec2-node → DOWN
```

Check:
1. EC2 Public IP is correct in `prometheus.yml`
2. Port 9100 is open in EC2 Security Group
3. Node Exporter is running on EC2:
   ```bash
   ssh -i key.pem ubuntu@EC2_IP
   sudo systemctl status node_exporter
   ```

---

### Grafana: Data source error

```
Error: connection refused
```

Fix: Use `http://prometheus:9090` (container name) — not `localhost:9090`

---

### No data in dashboard

1. Check Prometheus Targets page — must show **UP**
2. Change dashboard time range to **Last 15 minutes**
3. Check the Data Source is selected in the dashboard

---

## 🔑 Ports Reference

| Service | Where | Port |
|---|---|---|
| Node Exporter | EC2 | 9100 |
| Prometheus | Local Docker | 9090 |
| Grafana | Local Docker | 3000 |

---


sudo apt update
sudo apt install -y stress-ng
