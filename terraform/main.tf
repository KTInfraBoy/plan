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

# ── IAM Role (SSM 접속용) ────────────────────────────────────
resource "aws_iam_role" "ec2_ssm" {
  name = "${var.project}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.project}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name
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

# ── 보안그룹 — DB ─────────────────────────────────────────────
resource "aws_security_group" "db" {
  name   = "${var.project}-sg-db"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-sg-db" }
}

# ── DB EC2 (Private Subnet) ───────────────────────────────────
resource "aws_instance" "db" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.db.id]
  key_name               = aws_key_pair.infraboy.key_name
  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user

    docker run -d \
      --name postgres \
      --restart always \
      -e POSTGRES_USER=scott \
      -e POSTGRES_PASSWORD=tiger \
      -e POSTGRES_DB=scott_db \
      -p 5432:5432 \
      postgres:16
  EOF

  tags = { Name = "${var.project}-db" }
}

# ── Launch Template (App ASG용) ───────────────────────────────
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project}-lt-"
  image_id      = var.ami_id != "" ? var.ami_id : data.aws_ami.al2023.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.infraboy.key_name

  vpc_security_group_ids = [aws_security_group.ec2.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Docker 설치 (packer AMI에는 이미 있으므로 없을 때만 설치)
    if ! command -v docker &>/dev/null; then
      dnf install -y docker
      usermod -aG docker ec2-user
      systemctl enable docker
    fi
    systemctl start docker

    # docker-compose 설치 (packer AMI에는 이미 있음)
    if ! command -v docker-compose &>/dev/null; then
      curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
        -o /usr/local/bin/docker-compose
      chmod +x /usr/local/bin/docker-compose
    fi

    # nginx.conf 생성 (packer AMI에는 이미 있음)
    if [ ! -f /home/ec2-user/nginx.conf ]; then
      cat > /home/ec2-user/nginx.conf << 'NGINX'
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
    fi

    # docker-compose.prod.yml 생성 (packer AMI에는 이미 있음)
    if [ ! -f /home/ec2-user/docker-compose.prod.yml ]; then
      cat > /home/ec2-user/docker-compose.prod.yml << 'COMPOSE'
    services:
      app:
        image: jj3061/fastapi-app:latest
        environment:
          - DB_URL=$${DB_URL}
        restart: always
      nginx:
        image: nginx:alpine
        ports:
          - "80:80"
        volumes:
          - /home/ec2-user/nginx.conf:/etc/nginx/conf.d/default.conf:ro
        depends_on:
          - app
        restart: always
      node_exporter:
        image: prom/node-exporter
        network_mode: host
        pid: host
        volumes:
          - /:/host:ro
        command: --path.rootfs=/host
        restart: always
    COMPOSE
    fi

    # DB URL 설정 및 앱 실행
    echo "DB_URL=postgresql://scott:tiger@${aws_instance.db.private_ip}:5432/scott_db" \
      > /home/ec2-user/.env

    cd /home/ec2-user
    docker-compose --env-file .env -f docker-compose.prod.yml up -d
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.project}-asg" }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── Auto Scaling Group ────────────────────────────────────────
resource "aws_autoscaling_group" "app" {
  name                      = "${var.project}-asg"
  desired_capacity          = var.desired_capacity
  min_size                  = var.min_size
  max_size                  = var.max_size
  vpc_zone_identifier       = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-asg"
    propagate_at_launch = true
  }
}

# ── 예약 스케일링 ─────────────────────────────────────────────
resource "aws_autoscaling_schedule" "scale_up" {
  count = var.scale_up_cron != "" ? 1 : 0

  scheduled_action_name  = "scheduled-scale-up"
  autoscaling_group_name = aws_autoscaling_group.app.name
  desired_capacity       = var.scale_up_capacity
  min_size               = var.min_size
  max_size               = var.max_size
  recurrence             = var.scale_up_cron
  time_zone              = "Asia/Seoul"
}

resource "aws_autoscaling_schedule" "scale_down" {
  count = var.scale_down_cron != "" ? 1 : 0

  scheduled_action_name  = "scheduled-scale-down"
  autoscaling_group_name = aws_autoscaling_group.app.name
  desired_capacity       = var.scale_down_capacity
  min_size               = var.min_size
  max_size               = var.max_size
  recurrence             = var.scale_down_cron
  time_zone              = "Asia/Seoul"
}
