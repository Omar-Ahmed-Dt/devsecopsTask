# Monitoring & Observability Recommendation

## Stack

- **For Metrics**: Add kube-prometheus-stack `Prometheus` , `Alertmanager` , `Grafana`, deployed via Helm chart , in a dedicated `monitoring` namespace and ships it with pre-built dashboards and alert rules for cluster.
    - Prometheus: stores and queries metrics.
    - Alertmanager: sends alerts to Slack/email/etc.
    - Grafana: dashboards.
    - Kube-state-metrics: Kubernetes object metrics.
    - Node-exporter: node/VM metrics.

- **For Logs**: Add `Loki` , `Promtail` via Helm for log aggregation , and in a dedicated `monitoring` namespace
    - Promtail runs on every node and reads **container logs**
    - Loki stores logs.
    - Grafana displays both metrics and logs in the same UI.

---

## What to Scrape
which metrics should Prometheus collect?

### Cluster Level
- **kube-state-metrics**: Kubernetes object state: `kube_deployment_status_replicas_unavailable`, `kube_pod_status_phase`, `kube_pod_container_status_restarts_total`, `kube_horizontalpodautoscaler`.
- **Kubernetes API server**: request latency and error rate via `apiserver_request` metrics.

### Node Level
- **node-exporter** (DaemonSet): CPU saturation, memory pressure, disk I/O, and filesystem usage.

### App Level - podinfo
Podinfo exposes a Prometheus endpoint on port **9797** `--port-metrics=9797`. The deployment already carries the annotations `prometheus.io/scrape: "true"` and `prometheus.io/port: "9797"`,This means podinfo already exposes application metrics, so Prometheus can scrape it.
- `http_requests_total`: request rate by status code; use to derive error ratio.
- `http_request_duration_seconds`: latency histogram; p99 is the primary SLI.
- `/readyz` and `/healthz` are also consumed by kubelet liveness/readiness probes, so probe failures surface in kube-state-metrics restart counts.

### App-level - Redis
Redis does not expose Prometheus metrics natively. Deploy **redis-exporter** as a sidecar or standalone Deployment pointed at `redis.shop.svc.cluster.local:6379`. Scrape via a ServiceMonitor. Key metrics:
- `redis_connected_clients` - sudden drop signals a crash.
- `redis_commands_processed_total` - throughput baseline.
- `redis_keyspace_hits_total` / `redis_keyspace_misses_total` - cache effectiveness.
- `redis_memory_used_bytes` vs. the 256 Mi container limit - eviction risk.

---

## Alerting

| Alert | Condition | Severity |
|---|---|---|
| Pod crash-looping | `kube_pod_container_status_restarts_total` increases > 3 in 10 min | critical |
| Podinfo high error rate | `http_requests_total{status=~"5.."}` / total > 5% for 5 min | warning |
| Podinfo high p99 latency | `http_request_duration_seconds` p99 > 1 s for 5 min | warning |
| Redis unavailable | `redis_up == 0` for 1 min | critical |
| Redis memory near limit | `redis_memory_used_bytes` > 200 Mi (78% of 256 Mi limit) | warning |
| Node memory pressure | `node_memory_MemAvailable_bytes` < 200 Mi | warning |
| Node disk filling | `node_filesystem_avail_bytes{mountpoint="/"}` < 10% | warning |
| Deployment replica shortage | `kube_deployment_status_replicas_unavailable{deployment="podinfo"} > 0` for 5 min | critical |


---

## Logs

**Promtail** (DaemonSet) tails container stdout/stderr from `/var/log/pods/` and ships to **Loki**.

Key log signals to surface in Grafana:
- Podinfo `"level=error"` lines — correlate with the HTTP error-rate alert.
- Redis `"WRONGPASS"` / `"ERR"` lines — surfaced via Loki label filters in dashboards.
- k3s system logs via journald (Promtail supports journald input) for node-level events.

Log retention with an object-store backend (Like: S3) to avoid local disk pressure on the k3s nodes.
