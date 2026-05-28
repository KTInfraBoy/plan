# Task 06 — 데이터베이스 구성

온프레미스 Core DB (원천 데이터) + AWS RDS Slave (Read 캐싱 전용). **Volume은 필수** — 없으면 컨테이너 종료 시 데이터 소멸.

## 구성

```
온프레미스                    AWS
┌─────────────┐              ┌──────────────────┐
│  Core DB    │──Replication→│  RDS Slave       │
│ (Write/Read)│              │  (Read Only)     │
│  + Volume   │              │  + EBS Volume    │
└─────────────┘              └──────────────────┘
```

## 체크리스트

### 온프레미스 Core DB
- [ ] PostgreSQL 컨테이너 실행 (Volume 마운트 필수)
- [ ] DB 초기화 스크립트 작성
- [ ] 백업 정책 설정
- [ ] 복제 설정 (→ AWS RDS Slave)

### AWS RDS Slave
- [ ] RDS Read Replica 생성
- [ ] 보안그룹 설정 (EC2 → RDS only)
- [ ] FastAPI에서 Read 쿼리는 Slave로 라우팅

## docker-compose.yml (Core DB)

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_DB: appdb
      POSTGRES_USER: user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - db_data:/var/lib/postgresql/data   # Volume 필수
      - ./db/init.sql:/docker-entrypoint-initdb.d/init.sql

volumes:
  db_data:   # named volume — 컨테이너 삭제해도 데이터 유지
```

## Volume vs Bind Mount

| | Volume | Bind Mount |
|--|--------|-----------|
| DB 데이터 | ✅ 사용 | 비권장 |
| Nginx 설정 | | ✅ 사용 |
| 데이터 위치 | Docker 관리 | 호스트 경로 직접 지정 |
