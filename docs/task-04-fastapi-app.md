# Task 04 — FastAPI 앱 개발

서비스의 핵심 백엔드. Docker 컨테이너로 EC2 및 온프레미스에서 실행.

## 체크리스트

- [ ] 프로젝트 구조 설계
- [ ] API 엔드포인트 정의
- [ ] DB 연결 설정 (SQLAlchemy / 환경변수)
- [ ] 환경변수 `.env` 관리
- [ ] `requirements.txt` 정리
- [ ] Dockerfile 작성 (Task 03 참고)
- [ ] 헬스체크 엔드포인트 (`GET /health`)

## 프로젝트 구조

```
app/
├── main.py
├── routers/
│   └── *.py
├── models/
│   └── *.py
├── schemas/
│   └── *.py
├── core/
│   └── config.py       ← 환경변수 로드
├── requirements.txt
├── Dockerfile
└── .env.example
```

## 환경변수 관리

```env
# .env.example
DATABASE_URL=postgresql://user:pass@db:5432/appdb
SECRET_KEY=changeme
DEBUG=false
```

```python
# core/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str
    secret_key: str
    debug: bool = False

    class Config:
        env_file = ".env"
```

## 헬스체크

```python
@app.get("/health")
def health():
    return {"status": "ok"}
```

ALB / Nginx가 이 엔드포인트로 헬스체크 수행.
