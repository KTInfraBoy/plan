# Task 05 — Nginx 컨테이너 설정

Reverse Proxy + 로드밸런서 역할. 설정파일을 bind mount해서 컨테이너 재시작 없이 동적으로 변경 가능.

## 핵심 개념

```
호스트 디렉토리 (./nginx/nginx.conf)
        ↕ bind mount
컨테이너 내부 (/etc/nginx/nginx.conf)

→ 호스트에서 파일 수정 → nginx reload → 설정 즉시 반영
```

## 체크리스트

- [ ] `nginx/nginx.conf` 작성
- [ ] `docker-compose.yml`에 bind mount 설정
- [ ] FastAPI upstream 연결 확인
- [ ] 헬스체크 설정
- [ ] SSL/TLS 설정 (선택)

## docker-compose.yml

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app
```

## nginx.conf 예시

```nginx
upstream fastapi {
    server app:8000;
}

server {
    listen 80;

    location / {
        proxy_pass http://fastapi;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /health {
        proxy_pass http://fastapi/health;
    }
}
```

## 설정 변경 → reload

```bash
# 컨테이너 재시작 없이 설정 반영
docker exec <nginx_container> nginx -s reload
```
