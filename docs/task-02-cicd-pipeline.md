# Task 02 — GitHub Actions CI/CD 파이프라인

코드 Push 시 자동으로 보안 스캔 + 비용 예측 + Docker 빌드까지 수행.

## 파이프라인 흐름

```
git push → GitHub Actions 트리거
    ├─ Trivy     → 보안 취약점 스캔
    ├─ Infracost → 비용 예측 리포트
    └─ Docker Build → Docker Hub push
              └─ Discord / Slack / Telegram 알림
```

## 체크리스트

- [ ] `.github/workflows/ci.yml` 작성
- [ ] Trivy 스캔 step 추가
- [ ] Infracost step 추가 (`infracost diff`)
- [ ] Docker Build & Push step 추가
- [ ] Discord / Slack Webhook Secret 등록 (`Settings → Secrets`)
- [ ] 알림 포맷 정의 (보안 등급, 예상 비용 변화량)

## 워크플로우 skeleton

```yaml
# .github/workflows/ci.yml
name: CI Pipeline
on:
  push:
    branches: [main]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: fs

  cost:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Infracost
        uses: infracost/actions/setup@v3
      - run: infracost diff --path=.

  docker:
    needs: [security]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: yourteam/fastapi-app:latest
```

## Secrets 목록

| Key | 설명 |
|-----|------|
| `DOCKERHUB_USERNAME` | Docker Hub 계정 |
| `DOCKERHUB_TOKEN` | Docker Hub Access Token |
| `DISCORD_WEBHOOK_URL` | Discord 알림 웹훅 |
| `INFRACOST_API_KEY` | Infracost API 키 |
