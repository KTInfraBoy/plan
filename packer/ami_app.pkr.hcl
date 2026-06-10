# ============================================================
# infraboy AMI 빌드
#
# 굽는 것:
#   - Docker + docker-compose (컨테이너 런타임)
#   - nginx.conf, docker-compose.prod.yml (설정 파일)
#
# 굽지 않는 것 (user_data에서 pull):
#   - nginx, node_exporter, fastapi-app 이미지
#   → 앱 업데이트 시 AMI 재빌드 불필요
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

variable "region" {
  default = "ap-northeast-2"
}

variable "instance_type" {
  default = "t3.micro"
}

source "amazon-ebs" "app_image" {
  ami_name      = "infraboy-app-{{timestamp}}"
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
    Name    = "infraboy-app"
    Project = "infraboy"
    Base    = "amazonlinux2023"
  }
}

build {
  sources = ["source.amazon-ebs.app_image"]

  provisioner "ansible" {
    playbook_file = "./docker_setup.yml"
    user          = "ec2-user"
    use_proxy     = false
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
