# Task 01 — MGMT 마스터 서버 구성

중앙에서 인프라 전체를 제어하는 서버. 팀원들이 여기서 Terraform 실행, 스케일링 웹훅 발송, 로그 수집을 수행한다.

## 체크리스트

- [ ] OS 설치 및 기본 보안 설정 (SSH 키 인증, 방화벽)
- [ ] Docker 설치
- [ ] Terraform 설치
- [ ] Ansible 설치 (선택)
- [ ] GitHub Actions Runner 등록 (self-hosted)
- [ ] 팀원 SSH 공개키 등록

## 주요 명령어

```bash
# Docker 설치 (Ubuntu)
curl -fsSL https://get.docker.com | sh
usermod -aG docker $USER

# Terraform 설치
wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip
unzip terraform_1.7.0_linux_amd64.zip && mv terraform /usr/local/bin/

# GitHub Actions self-hosted runner 등록
# GitHub Repo → Settings → Actions → Runners → New self-hosted runner
```

## 연결 관계

```
MGMT ──→ AWS ASG (웹훅 Scale 제어)
MGMT ──→ S3 / 원격 로그 스토리지
MGMT ←── Prometheus (메트릭 수신)
MGMT ←── Grafana (대시보드 연동)
```
