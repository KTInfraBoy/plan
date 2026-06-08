output "alb_dns" {
  description = "ALB DNS — 브라우저에서 접속"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ec2_private_ip" {
  description = "EC2 Private IP — SSH 접속용"
  value       = aws_instance.app.private_ip
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "nat_public_ip" {
  description = "NAT Gateway 공인 IP"
  value       = aws_eip.nat.public_ip
}

output "ssh_command" {
  description = "SSH 접속 명령어 (Bastion 없이는 VPN 필요)"
  value       = "ssh -i infraboy.pem ec2-user@${aws_instance.app.private_ip}"
}
