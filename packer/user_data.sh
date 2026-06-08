#!/bin/bash
# EC2 부팅 시 자동 실행 — Terraform Launch Template에 삽입
# 역할: AMI에 없는 '인스턴스 개별 정보'만 처리

set -e
REGION="ap-northeast-2"

# ── SSM에서 민감정보 가져오기 ─────────────────────────────────
# (이성규 Terraform에서 SSM Parameter 등록 필요)
DB_URL=$(aws ssm get-parameter \
  --name "/infraboy/db_url" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region $REGION)

TAILSCALE_AUTHKEY=$(aws ssm get-parameter \
  --name "/infraboy/tailscale_authkey" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region $REGION)

# ── Tailscale 연결 (인스턴스마다 개별 인증) ──────────────────
tailscale up \
  --authkey=$TAILSCALE_AUTHKEY \
  --accept-routes \
  --hostname=infraboy-ec2-$(hostname)

# ── 서비스 시작 ───────────────────────────────────────────────
export DB_URL=$DB_URL
cd /home/ec2-user
docker compose -f docker-compose.prod.yml up -d
