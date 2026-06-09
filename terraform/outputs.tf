output "alb_dns" {
  description = "ALB DNS — 브라우저에서 접속"
  value       = "http://${aws_lb.main.dns_name}"
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "nat_public_ip" {
  description = "NAT Gateway 공인 IP"
  value       = aws_eip.nat.public_ip
}

output "db_private_ip" {
  description = "DB EC2 Private IP"
  value       = aws_instance.db.private_ip
}

output "asg_name" {
  description = "Auto Scaling Group 이름"
  value       = aws_autoscaling_group.app.name
}
