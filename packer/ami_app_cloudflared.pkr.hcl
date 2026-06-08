# ============================================================
# infraboy AMI 빌드 — cloudflared 역터널링 버전
# Tailscale 없음, cloudflared로 MGMT Prometheus 메트릭 수집
#
# 빌드: packer build ami_app_cloudflared.pkr.hcl
# ============================================================

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

# ── 소스 AMI 설정 ────────────────────────────────────────────
source "amazon-ebs" "app_image_cloudflared" {
  ami_name      = "infraboy-app-cloudflared-{{timestamp}}"
  instance_type = var.instance_type
  region        = var.region

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

  tags = {
    Name    = "infraboy-app-cloudflared"
    Project = "infraboy"
    Tunnel  = "cloudflared"
  }
}

# ── 빌드 ────────────────────────────────────────────────────
build {
  sources = ["source.amazon-ebs.app_image_cloudflared"]

  provisioner "ansible" {
    playbook_file = "./docker_setup_cloudflared.yml"
    user          = "ec2-user"
    use_proxy     = false
  }

  post-processor "manifest" {
    output     = "manifest_cloudflared.json"
    strip_path = true
  }
}
