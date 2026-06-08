terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  # tfstate 중앙 저장 (GitHub Actions 환경에서 필수)
  # 적용 전 S3 버킷과 DynamoDB 테이블을 먼저 생성해야 함
  backend "s3" {
    bucket         = "infraboy-tfstate"          # S3 버킷명
    key            = "terraform/infraboy.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "infraboy-tfstate-lock"     # 동시 apply 방지 락 테이블
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}

# ── 최신 Amazon Linux 2023 AMI ───────────────────────────────
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── SSH 키 생성 ───────────────────────────────────────────────
resource "tls_private_key" "infraboy" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "infraboy" {
  key_name   = "${var.project}-key"
  public_key = tls_private_key.infraboy.public_key_openssh
}

resource "local_file" "pem" {
  content         = tls_private_key.infraboy.private_key_pem
  filename        = "${path.module}/${var.project}.pem"
  file_permission = "0400"
}

# ── VPC ───────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "${var.project}-vpc" }
}

# ── Internet Gateway ──────────────────────────────────────────
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-igw" }
}

# ── Public Subnet (2개 — ALB 요구사항) ───────────────────────
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = { Name = "${var.project}-public-a" }
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}c"
  map_public_ip_on_launch = true
  tags = { Name = "${var.project}-public-c" }
}

# ── Private Subnet (2개) ──────────────────────────────────────
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.region}a"
  tags = { Name = "${var.project}-private-a" }
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "${var.region}c"
  tags = { Name = "${var.project}-private-c" }
}

# ── NAT Gateway (Public Subnet에 위치) ───────────────────────
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "${var.project}-nat" }
  depends_on    = [aws_internet_gateway.igw]
}

# ── Route Tables ──────────────────────────────────────────────
# Public: IGW로 라우팅
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project}-rt-public" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

# Private: NAT로 라우팅
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "${var.project}-rt-private" }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private.id
}

# ── 보안그룹 — ALB ────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name   = "${var.project}-sg-alb"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project}-sg-alb" }
}

# ── 보안그룹 — EC2 ────────────────────────────────────────────
resource "aws_security_group" "ec2" {
  name   = "${var.project}-sg-ec2"
  vpc_id = aws_vpc.main.id

  # ALB에서만 80 허용
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # 내 IP에서만 SSH 허용
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # 메트릭 수집 (MGMT → EC2)
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project}-sg-ec2" }
}

# ── ALB ───────────────────────────────────────────────────────
resource "aws_lb" "main" {
  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_c.id]
  tags               = { Name = "${var.project}-alb" }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
  tags = { Name = "${var.project}-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ── EC2 테스트 인스턴스 (Private Subnet) ─────────────────────
resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.infraboy.key_name

  user_data = <<-EOF
    #!/bin/bash
    # Docker 설치
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker ec2-user
    systemctl enable docker
    systemctl start docker

    # docker-compose 설치
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # nginx 설정 파일 생성
    mkdir -p /home/ec2-user/app
    cat > /home/ec2-user/app/nginx.conf << 'NGINX'
server {
    listen 80;
    location / {
        proxy_pass         http://app:8000;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_read_timeout 10s;
    }
    location /health {
        proxy_pass http://app:8000/health;
        access_log off;
    }
}
NGINX

    # 앱 실행 (로컬 DB 포함 개발용 compose 사용)
    cat > /home/ec2-user/app/docker-compose.yml << 'COMPOSE'
    services:
      app:
        image: jj3061/fastapi-app:latest
        environment:
          - DB_URL=postgresql://scott:tiger@db:5432/scott_db
        ports:
          - "8000:8000"
        depends_on:
          db:
            condition: service_healthy
        restart: always
      nginx:
        image: nginx:alpine
        ports:
          - "80:80"
        volumes:
          - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
        depends_on:
          - app
        restart: always
      db:
        image: postgres:16
        environment:
          POSTGRES_USER: scott
          POSTGRES_PASSWORD: tiger
          POSTGRES_DB: scott_db
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U scott -d scott_db"]
          interval: 10s
          timeout: 5s
          retries: 5
        restart: always
    COMPOSE

    cd /home/ec2-user/app
    docker-compose up -d
  EOF

  tags = { Name = "${var.project}-app-test" }
}

# ── ALB Target Group에 EC2 등록 ───────────────────────────────
resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = 80
}
