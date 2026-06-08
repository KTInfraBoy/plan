# Infraboy 프로젝트 문서

## 프로젝트 개요

하이브리드 클라우드(온프레미스 + AWS) 환경에서 DevSecOps / AIOps 파이프라인을 구축하는 팀 프로젝트.

## 아키텍처 구조

```
PHASE 1: Shift-Left CI/CD 파이프라인
  로컬 → GitHub → GitHub Actions → Trivy/Infracost → Docker Build → Docker Hub → ChatOps 알림

PHASE 2: 하이브리드 운영 (Observability & AIOps)
  온프레미스(MGMT + Prometheus + Grafana + Nginx + DB)
  ↔ VPN 터널 ↔
  AWS(IGW → ALB → ASG → EC2 Docker 컨테이너)

PHASE 3: Privacy DevSecOps / AI 로그 분석
  Core DB → Regex Masking(비식별화) → Gemini AI → ChatOps 장애 알림
```

## 아키텍처 다이어그램

[`architecture.drawio`](../architecture.drawio) — draw.io에서 열기

---

## 태스크 목록

| 태스크 | 파일 | 담당 영역 |
|--------|------|-----------|
| Task 01 | [mgmt-server.md](./task-01-mgmt-server.md) | MGMT 마스터 서버 초기 구성 |
| Task 02 | [cicd-pipeline.md](./task-02-cicd-pipeline.md) | GitHub Actions CI/CD 파이프라인 |
| Task 03 | [docker-pipeline.md](./task-03-docker-pipeline.md) | Docker 이미지 빌드 & 배포 |
| Task 04 | [fastapi-app.md](./task-04-fastapi-app.md) | FastAPI 앱 개발 |
| Task 05 | [nginx.md](./task-05-nginx.md) | Nginx 컨테이너 설정 |
| Task 06 | [database.md](./task-06-database.md) | 데이터베이스 구성 |
| Task 07 | [monitoring.md](./task-07-monitoring.md) | Prometheus + Grafana 모니터링 |
| Task 08 | [aws-infra.md](./task-08-aws-infra.md) | AWS 인프라 (Terraform) |
| Task 09 | [privacy-aiops.md](./task-09-privacy-aiops.md) | Privacy AIOps / AI 로그 분석 |

---

## 추가 문서

| 문서 | 파일 | 내용 |
|------|------|------|
| 전체 프로젝트 흐름 | [project-flow.md](./project-flow.md) | Phase 0~6 타임라인, 팀원별 핸드오프 |
| 각 기술 동작 원리 | [how-each-works.md](./how-each-works.md) | Terraform, Docker, Ansible, Prometheus 등 상세 설명 |
| 최진제 개발 계획 | [plan-최진제.md](./plan-최진제.md) | Docker/Ansible/Packer 개발 순서 |
| 멘토링 준비 가이드 | [mentoring-prep.md](./mentoring-prep.md) | 현직자 멘토링 질문 목록 및 준비 자료 |
| 장애 대응 가이드 | [incident-response.md](./incident-response.md) | 장애 유형별 증상, 원인, 대응 명령어 |
| AIOps 자동 장애 대응 | [aiops-incident-automation.md](./aiops-incident-automation.md) | Gemini 분류 → 자동 스크립트 실행 시스템 |

---

## 핵심 KPI

| 지표 | 목표 |
|------|------|
| 보안 취약점 배포 전 차단율 | 100% |
| 인프라 비용 예측 정확도 | 실제 비용 대비 ±10% 이내 |
| 장애 예측 선행 시간 | 실제 장애 발생 30분 전 감지 |
| AI 로그 분석 MTTR 단축 | 기존 대비 50% 이하 |
