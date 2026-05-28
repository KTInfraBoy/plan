# Task 07 — Prometheus + Grafana 모니터링

온프레미스 Prometheus가 VPN 터널을 통해 AWS EC2 메트릭까지 수집. 선형회귀 예측으로 장애 30분 전 감지.

## 구성

```
AWS EC2 (node_exporter)
    │
    │ VPN Tunnel (Pull)
    ↓
Prometheus (온프레미스)
    │ 선형회귀 예측 쿼리
    ↓
MGMT → Scale 제어 웹훅 → ASG
    │
    ↓
Grafana 대시보드 (수동 스케일링 예약 UI)
```

## 체크리스트

- [ ] Prometheus 컨테이너 실행 (`prometheus.yml` bind mount)
- [ ] 각 노드에 `node_exporter` 설치
- [ ] VPN 터널로 AWS EC2 메트릭 수집 설정
- [ ] 선형회귀 예측 쿼리 작성 (`predict_linear`)
- [ ] Grafana 컨테이너 실행 (Volume 마운트)
- [ ] Grafana → Prometheus 데이터소스 연결
- [ ] 알림 규칙 (Alertmanager → ChatOps)

## Prometheus 선형회귀 예측 쿼리

```promql
# 30분 후 메모리 사용량 예측
predict_linear(
  node_memory_MemAvailable_bytes[1h],
  30 * 60
) < 0
```

→ 예측값이 0 미만이면 메모리 부족 예상 → 알림 발송

## prometheus.yml

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'onprem'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'aws-ec2'
    static_configs:
      - targets:
          - 'ec2-1-private-ip:9100'
          - 'ec2-2-private-ip:9100'
          - 'ec2-3-private-ip:9100'
```

## docker-compose.yml

```yaml
services:
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prom_data:/prometheus

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana

volumes:
  prom_data:
  grafana_data:
```
