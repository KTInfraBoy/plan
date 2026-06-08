#!/bin/bash
# EC2 부팅 시 자동 실행 — cloudflared 역터널링 버전
# Tailscale 없음, cloudflared로 MGMT Prometheus와 연결

set -e
REGION="ap-northeast-2"

# ── SSM에서 민감정보 가져오기 ─────────────────────────────────
DB_URL=$(aws ssm get-parameter \
  --name "/infraboy/db_url" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region $REGION)

CLOUDFLARE_TUNNEL_TOKEN=$(aws ssm get-parameter \
  --name "/infraboy/cloudflare_tunnel_token" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region $REGION)

# ── 서비스 시작 ───────────────────────────────────────────────
export DB_URL=$DB_URL
export CLOUDFLARE_TUNNEL_TOKEN=$CLOUDFLARE_TUNNEL_TOKEN
cd /home/ec2-user
docker compose -f docker-compose.prod.cloudflared.yml up -d
