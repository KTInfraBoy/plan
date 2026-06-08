variable "region" {
  default = "ap-northeast-2"
}

variable "project" {
  default = "infraboy"
}

variable "my_ip" {
  description = "SSH 허용할 내 공인 IP (예: 123.456.789.0/32)"
}
