# ============================================================
# infraboy AMI 빌드
# 수업 test07_packer/ami_web.pkr.hcl 패턴 확장
#
# 굽는 것:
#   - Docker
#   - node_exporter (Prometheus 메트릭 수집용)
#   - Tailscale (MGMT 서버 ↔ EC2 VPN)
#
# 굽지 않는 것:
#   - FastAPI 앱 이미지 (배포마다 바뀌니까 → UserData에서 pull)
# ============================================================

# ── 플러그인 선언 (수업과 동일) ─────────────────────────────
packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

# ── 변수 ────────────────────────────────────────────────────
variable "region" {
  default = "ap-northeast-2"
}

variable "instance_type" {
  default = "t3.micro"
}

# Tailscale Auth Key (민감정보 → 환경변수로 주입)
# 빌드 시: export PKR_VAR_tailscale_authkey="tskey-auth-xxx"
variable "tailscale_authkey" {
  sensitive = true
}

# ── 소스 AMI 설정 ────────────────────────────────────────────
# 수업 test07_packer와 동일한 구조
source "amazon-ebs" "app_image" {
  # 만들어질 AMI 이름 (timestamp로 고유하게)
  ami_name      = "infraboy-app-{{timestamp}}"
  instance_type = var.instance_type
  region        = var.region

  # 베이스: Amazon Linux 2023 최신
  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  ssh_username = "ec2-user"

  # 만들어진 AMI 태그
  tags = {
    Name    = "infraboy-app"
    Project = "infraboy"
    Base    = "amazonlinux2023"
  }
}

# ── 빌드 순서 ────────────────────────────────────────────────
build {
  sources = ["source.amazon-ebs.app_image"]

  # ① Ansible playbook 실행 (수업과 동일한 방식)
  #    nginx_setup.yml → docker_setup.yml 로 바꾼 것
  provisioner "ansible" {
    playbook_file = "./docker_setup.yml"
    user          = "ec2-user"
    use_proxy     = false

    # Tailscale authkey를 playbook에 변수로 전달
    extra_arguments = [
      "--extra-vars", "tailscale_authkey=${var.tailscale_authkey}"
    ]
  }

  # ② 완성된 AMI ID 출력
  post-processor "manifest" {
    output     = "manifest.json"    # AMI ID 여기에 저장됨
    strip_path = true
  }
}
