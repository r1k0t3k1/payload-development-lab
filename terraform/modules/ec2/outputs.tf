output "dev_global_ip" {
  type        = string
  description = "DEVの外部IP"
  value = aws_instance.dev.public_ip
}

output "dev_credential" {
  value = "dev:${local.password}"
}

output "dev_ssh_key" {
  value = "${local.dev_sshkey_filename}"
}

output "elk_private_ip" {
  type        = string
  description = "ELKの内部IP"
  value = aws_instance.elk.private_ip
}

output "elk_ssh_key" {
  value = "${local.elk_sshkey_filename}"
}

output "victim_private_ip" {
  type        = string
  description = "VICTIMの内部IP"
  value = aws_instance.victim.private_ip
}

output "attacker_private_ip" {
  type        = string
  description = "ATTACKERの内部IP"
  value = aws_instance.attacker.private_ip
}

output "attacker_ssh_key" {
  value = "${local.attacker_sshkey_filename}"
}

output "victim_ssh_key" {
  value = "${local.victim_sshkey_filename}"
}
