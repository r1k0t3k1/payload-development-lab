output "dev_global_ip" {
  value = module.ec2.dev_global_ip
}

output "dev_credential" {
  value = module.ec2.dev_credential
}

output "dev_sshkey" {
  value = nonsensitive(module.ec2.dev_ssh_key)
}

output "elk_private_ip" {
  value = module.ec2.elk_private_ip
}

output "elk_sshkey" {
  value = nonsensitive(module.ec2.elk_ssh_key)
}

output "victim_private_ip" {
  value = module.ec2.victim_private_ip
}

output "attacker_private_ip" {
  value = module.ec2.attacker_private_ip
}

output "attacker_sshkey" {
  value = nonsensitive(module.ec2.attacker_ssh_key)
}
