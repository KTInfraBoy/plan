# Task 03 — Docker 이미지 빌드 & 배포

팀이 만든 FastAPI 앱을 이미지로 만들어 Docker Hub에 올리고, 각 노드에서 pull해서 실행.

## 흐름

```
소스코드 작성
    → Dockerfile 작성
    → docker build -t yourteam/fastapi-app:latest .
    → docker push yourteam/fastapi-app:latest       ← CI/CD 자동화
    
각 노드에서:
    → docker pull yourteam/fastapi-app:latest
    → docker run -d -p 8000:8000 yourteam/fastapi-app:latest
```

## 체크리스트

- [ ] FastAPI 앱 Dockerfile 작성
- [ ] `.dockerignore` 작성
- [ ] Docker Hub 팀 레포지토리 생성
- [ ] GitHub Actions에서 자동 build/push 연결 (Task 02 참고)
- [ ] 각 노드에서 pull 후 실행 확인
- [ ] 이미지 태그 전략 정의 (`latest` + `git SHA`)

## Dockerfile 예시

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## 이미지 태그 전략

| 태그 | 용도 |
|------|------|
| `latest` | 최신 main 브랜치 |
| `git-abc1234` | 특정 커밋 추적 |
| `v1.0.0` | 릴리스 버전 |

## 공식 이미지 (직접 pull해서 쓰는 것들)

| 서비스 | Docker Hub 이미지 |
|--------|------------------|
| Nginx | `nginx:alpine` |
| Prometheus | `prom/prometheus` |
| Grafana | `grafana/grafana` |
| PostgreSQL | `postgres:16` |
