output "ssh_key_name" {
  description = "SSH Key for EC2 instance login"
  value       = "${aws_key_pair.ec2-example-ssh-key.key_name}"
}

output "ALB_DNS" {
  value = aws_lb.terraformALB.dns_name
}