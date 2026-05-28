# Task 08 — AWS 인프라 (Terraform)

VPC / ALB / ASG / EC2 구성. Terraform으로 코드화해서 팀이 동일한 환경 재현 가능.

## 구성도

```
Internet
    │
   IGW
    │
   ALB  (Public Subnet)
    │
   ASG
  / | \
EC2 EC2 EC2  (Private Subnet) — Docker 컨테이너 실행
         │
      RDS Slave (Read)
```

## 체크리스트

- [ ] VPC + Subnet (Public/Private) 생성
- [ ] Internet Gateway 연결
- [ ] ALB 생성 + 헬스체크 설정 (`/health`)
- [ ] Launch Template 작성 (EC2 + Docker user_data)
- [ ] Auto Scaling Group 생성
- [ ] RDS Read Replica 생성
- [ ] 보안그룹 설정
- [ ] MGMT → ASG 웹훅 IAM 권한 설정

## 디렉토리 구조

```
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── modules/
│   ├── vpc/
│   ├── alb/
│   ├── asg/
│   └── rds/
└── terraform.tfvars
```

## EC2 user_data (Docker 설치 + 앱 실행)

```bash
#!/bin/bash
curl -fsSL https://get.docker.com | sh
docker pull yourteam/fastapi-app:latest
docker run -d -p 8000:8000 \
  -e DATABASE_URL=${DATABASE_URL} \
  yourteam/fastapi-app:latest
```

## 보안그룹 규칙

| 리소스 | 인바운드 | 소스 |
|--------|---------|------|
| ALB | 80, 443 | 0.0.0.0/0 |
| EC2 | 8000 | ALB SG only |
| EC2 | 9100 (node_exporter) | MGMT IP (VPN) |
| RDS | 5432 | EC2 SG only |

## MGMT에서 ASG 스케일링 웹훅

```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name my-asg \
  --desired-capacity 5
```
