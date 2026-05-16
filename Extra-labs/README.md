# 📊 Monitoring Labs — Prometheus & Grafana

> **DevOps DIGILIANCE** — Monitoring Track

Two complete hands-on labs to build a production-grade monitoring stack from scratch.

---

## 📁 Repository Structure

```
monitoring-labs/
├── lab1/                          ← Monitor EC2 on AWS
│   ├── prometheus.yml             ← Prometheus scrape config
│   ├── docker-compose.yml         ← Run Prometheus + Grafana together
│   ├── node-exporter.service      ← systemd service file
│   └── setup.sh                   ← Automated setup script
│
├── lab2/                          ← Monitor Minikube 2-Node Cluster
│   ├── values.yml                 ← Helm values for kube-prometheus-stack
│   ├── nginx-test.yaml            ← Test deployment (3 replicas)
│   └── load-generator.yaml        ← Load generator pod
│
└── README.md                      ← This file
```

---

## 🗺️ Architecture

```
Lab 1 — EC2 Monitoring:
  EC2 (Node Exporter :9100) ──scrape──▶ Prometheus (:9090) ──query──▶ Grafana (:3000)

Lab 2 — Kubernetes Monitoring:
  Node 1 (node-exporter pod)  ──┐
  Node 2 (node-exporter pod)  ──┤──▶ Prometheus (kube-prometheus-stack) ──▶ Grafana
  K8s API (kube-state-metrics)──┘
```

---

## 🖥️ Lab 1 — Monitor EC2 on AWS

### EC2 Requirements
| Setting | Value |
|---|---|
| OS | Ubuntu 22.04 |
| Instance Type | **t2.medium** (2 CPU, 4 GB RAM) |
| Ports (Security Group) | **22** (SSH), **9100** (Node Exporter), **9090** (Prometheus), **3000** (Grafana) |

### Part A — Launch EC2 and Install Docker

**1. Launch EC2:**
```
AWS Console → EC2 → Launch Instance
→ Ubuntu 22.04 → t2.medium → your Key Pair
→ Security Group: allow TCP 22, 9100, 9090, 3000 (source: 0.0.0.0/0)
→ Launch
```

**2. SSH into EC2:**
```bash
ssh -i your-key.pem ubuntu@EC2_PUBLIC_IP
```

**3. Install Docker:**
```bash
sudo apt update -y
sudo apt install -y docker.io docker-compose curl wget
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

# Logout and reconnect for group change
exit
ssh -i your-key.pem ubuntu@EC2_PUBLIC_IP

# Verify
docker ps
```

---

### Part B — Install Node Exporter

**4. Download and install:**
```bash
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar xvf node_exporter-1.8.2.linux-amd64.tar.gz
sudo mv node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-1.8.2.linux-amd64*
```

**5. Install as systemd service:**
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

**6. Verify:**
```bash
sudo systemctl status node_exporter
# Should show: Active: active (running)

curl http://localhost:9100/metrics | head -10
# Should show lines like:
# HELP node_cpu_seconds_total ...
# node_cpu_seconds_total{cpu="0",mode="idle"} 12345.6
```

> ✅ If you see metric lines — Node Exporter is working!

---

### Part C — Run Prometheus

**7. Clone this repo and go to lab1:**
```bash
git clone https://github.com/YOUR_USERNAME/monitoring-labs.git
cd monitoring-labs/lab1
```

**8. Check the prometheus.yml config:**
```bash
cat prometheus.yml
```

The file targets `172.17.0.1:9100` — this is the Docker bridge IP that allows the Prometheus container to reach Node Exporter running on the host.

> ⚠️ If `172.17.0.1` doesn't work, find the bridge IP with: `ip route | grep docker`

**9. Start Prometheus:**
```bash
docker run -d \
  --name prometheus \
  -p 9090:9090 \
  --add-host=host.docker.internal:host-gateway \
  -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml \
  -v prometheus_data:/prometheus \
  prom/prometheus
```

**10. Check Targets:**
```
Open: http://EC2_PUBLIC_IP:9090
→ Status → Targets
→ Both targets should show STATE: UP ✅
```

---

### Part D — Run Grafana

**11. Start Grafana:**
```bash
docker run -d \
  --name grafana \
  -p 3000:3000 \
  -v grafana_data:/var/lib/grafana \
  -e GF_SECURITY_ADMIN_PASSWORD=admin123 \
  grafana/grafana
```

**12. Open Grafana:**
```
http://EC2_PUBLIC_IP:3000
Username: admin
Password: admin123
```

**13. Add Prometheus as Data Source:**
```
Home → Connections → Data Sources → Add → Prometheus
URL: http://172.17.0.1:9090
→ Save & Test
→ Should show: Data source is working ✅
```

**14. Import Dashboard:**
```
Home → Dashboards → Import
Dashboard ID: 1860 → Load
Select Prometheus data source → Import
```

> 🎉 You now have a live Grafana dashboard showing CPU, RAM, Disk, Network!

---

### Part E — Alternative: Use docker-compose

Instead of running containers manually, use the included docker-compose:

```bash
cd monitoring-labs/lab1
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f prometheus
docker-compose logs -f grafana

# Stop
docker-compose down
```

---

### ✅ Lab 1 Verification Checklist

```bash
# 1. Node Exporter running
sudo systemctl status node_exporter

# 2. Metrics available
curl http://localhost:9100/metrics | grep node_cpu | head -3

# 3. Prometheus running
docker ps | grep prometheus

# 4. Both Targets UP
# → http://EC2_IP:9090/targets

# 5. Grafana running
docker ps | grep grafana

# 6. Dashboard 1860 showing data
# → http://EC2_IP:3000
```

---

## ☸️ Lab 2 — Monitor Minikube 2-Node Cluster

### EC2 Requirements
| Setting | Value |
|---|---|
| OS | Ubuntu 22.04 |
| Instance Type | **t3.large** (2 CPU, 8 GB RAM) — minimum for 2-node cluster |
| Ports (Security Group) | **22**, **3000**, **9090**, **30000-32767** |

### Part A — Install Prerequisites

**1. Launch EC2 t3.large** (same steps as Lab 1 but bigger instance).

**2. SSH in and install all tools:**
```bash
# Docker
sudo apt update -y
sudo apt install -y docker.io curl wget git
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu
exit && ssh -i key.pem ubuntu@EC2_IP  # reconnect

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl
kubectl version --client

# Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
minikube version

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

---

### Part B — Start Minikube with 2 Nodes

**3. Start the cluster:**
```bash
minikube start \
  --driver=docker \
  --nodes=2 \
  --cpus=2 \
  --memory=3000mb \
  --kubernetes-version=stable
```

> ⏳ This takes 3-5 minutes. Wait for: `Done! kubectl is now configured`

**4. Verify both nodes are Ready:**
```bash
kubectl get nodes

# Expected output:
# NAME           STATUS   ROLES           AGE   VERSION
# minikube       Ready    control-plane   2m    v1.32.x
# minikube-m02   Ready    <none>          1m    v1.32.x
```

**5. Check cluster info:**
```bash
kubectl cluster-info
kubectl get pods --all-namespaces
```

---

### Part C — Deploy kube-prometheus-stack

**6. Add Prometheus Helm repository:**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm repo list
```

**7. Create monitoring namespace:**
```bash
kubectl create namespace monitoring
kubectl get namespaces | grep monitoring
```

**8. Install the stack:**
```bash
# Clone repo if not already done
git clone https://github.com/YOUR_USERNAME/monitoring-labs.git
cd monitoring-labs/lab2

# Install with custom values
helm install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values values.yml
```

**9. Wait for all pods to be Running:**
```bash
kubectl get pods -n monitoring --watch
# Press Ctrl+C when all show Running

# All pods should be Running:
# kube-prometheus-stack-grafana-xxx              Running
# kube-prometheus-stack-prometheus-xxx           Running
# kube-prometheus-stack-alertmanager-xxx         Running
# kube-prometheus-stack-operator-xxx             Running
# node-exporter-xxx (one per node - 2 total)     Running
# kube-state-metrics-xxx                         Running
```

> ⚠️ Wait until ALL pods show `Running` — this can take 5 minutes.

---

### Part D — Access Grafana

**10. Get Grafana admin password:**
```bash
kubectl get secret --namespace monitoring \
  kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 --decode
echo ""
```

**11. Port-forward Grafana (open in a new terminal):**
```bash
kubectl port-forward --namespace monitoring \
  svc/kube-prometheus-stack-grafana \
  3000:80 --address 0.0.0.0
```

**12. Open Grafana:**
```
http://EC2_PUBLIC_IP:3000
Username: admin
Password: (from step 10)
```

---

### Part E — Explore Dashboards

**13. Node dashboard:**
```
Home → Dashboards → Browse
→ Kubernetes → Kubernetes / Nodes
→ Use node dropdown to switch between minikube and minikube-m02
```

**14. Pod dashboard:**
```
Home → Dashboards → Browse
→ Kubernetes → Kubernetes / Compute Resources / Pod
```

**15. Cluster overview:**
```
Home → Dashboards → Browse
→ Kubernetes → Kubernetes / Compute Resources / Cluster
```

---

### Part F — Deploy Test App and Generate Load

**16. Deploy nginx (3 replicas):**
```bash
kubectl apply -f monitoring-labs/lab2/nginx-test.yaml

# Wait for pods
kubectl get pods --watch
# Press Ctrl+C when 3 pods show Running
```

**17. Generate load:**
```bash
kubectl apply -f monitoring-labs/lab2/load-generator.yaml

# Watch logs
kubectl logs -f load-generator
```

**18. Watch in Grafana:**
```
Open: Kubernetes / Compute Resources / Pod
Namespace: default
→ watch CPU go up for nginx-test pods ↑
```

**19. Check both nodes:**
```bash
# kubectl commands to verify
kubectl get pods -o wide          # shows which node each pod is on
kubectl top nodes                 # CPU/RAM per node
kubectl top pods --namespace default
```

**20. Clean up:**
```bash
kubectl delete -f monitoring-labs/lab2/nginx-test.yaml
kubectl delete -f monitoring-labs/lab2/load-generator.yaml
```

---

## 🔧 Useful Commands

### Prometheus
```bash
# Check targets
curl http://localhost:9090/api/v1/targets | python3 -m json.tool

# PromQL queries
# CPU usage
curl 'http://localhost:9090/api/v1/query?query=100-(avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))*100)'

# RAM available
curl 'http://localhost:9090/api/v1/query?query=node_memory_MemAvailable_bytes'
```

### Kubernetes
```bash
# Check monitoring namespace
kubectl get all -n monitoring

# Restart a pod
kubectl rollout restart deployment/kube-prometheus-stack-grafana -n monitoring

# Uninstall the stack
helm uninstall kube-prometheus-stack -n monitoring

# Stop Minikube
minikube stop

# Delete Minikube cluster
minikube delete
```

---

## 🐛 Troubleshooting

### Lab 1

| Problem | Fix |
|---|---|
| Node Exporter DOWN in Prometheus | Check: `sudo systemctl status node_exporter` and port 9100 in Security Group |
| Grafana can't connect to Prometheus | Use `172.17.0.1:9090` not `localhost:9090` |
| Dashboard 1860 shows No Data | Check Prometheus Targets → both must be UP |

### Lab 2

| Problem | Fix |
|---|---|
| Minikube fails to start | Use t3.large — t2.micro has insufficient RAM |
| Pods stuck in Pending | `kubectl describe pod POD_NAME -n monitoring` — usually resource limits |
| Grafana unreachable | Make sure port-forward terminal is still running |
| node-exporter only on 1 node | Normal initially — waits for node 2 to be Ready |

---

## 📊 Ports Reference

| Service | Port | Lab |
|---|---|---|
| Node Exporter | 9100 | Lab 1 |
| Prometheus | 9090 | Lab 1 |
| Grafana | 3000 | Lab 1 & 2 |
| Grafana (NodePort) | 30080 | Lab 2 |
| Prometheus (NodePort) | 30090 | Lab 2 |

---

## 🎓 DevOps Scholarship — Monitoring Track
