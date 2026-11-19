output "dev_global_ip" {
  type        = string
  description = "DEVの外部IP"
  value = aws_instance.dev.public_ip
}

output "dev_credential" {
  value = "dev:${local.password}"
}

output "elk_private_ip" {
  type        = string
  description = "ELKの内部IP"
  value = aws_instance.elk.private_ip
}

output "victim_private_ip" {
  type        = string
  description = "VICTIMの内部IP"
  value = aws_instance.victim.private_ip
}

output "victim_credential" {
  value = "${local.victim_username}:${local.password}"
}

output "victim_admin_credential" {
  value = "${local.victim_admin_username}:${local.password}"
}

output "attacker_private_ip" {
  type        = string
  description = "ATTACKERの内部IP"
  value = aws_instance.attacker.private_ip
}
