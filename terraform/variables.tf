variable "region" {
  default = "ap-northeast-2"
}

variable "project" {
  default = "infraboy"
}

variable "my_ip" {
  description = "SSH 허용할 내 공인 IP (예: 123.456.789.0/32)"
}

variable "ami_id" {
  description = "Packer로 구운 AMI ID. 비어있으면 최신 Amazon Linux 2023 사용"
  default     = ""
}

# ── ASG 스케일링 ─────────────────────────────────────────────
variable "desired_capacity" {
  type    = number
  default = 1
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 4
}

variable "scale_up_capacity" {
  type    = number
  default = 0
}

variable "scale_up_cron" {
  type    = string
  default = ""
}

variable "scale_down_capacity" {
  type    = number
  default = 0
}

variable "scale_down_cron" {
  type    = string
  default = ""
}
