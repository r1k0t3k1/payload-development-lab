output "dev_global_ip" {
  value = module.ec2.dev_global_ip
}

output "dev_credential" {
  value = module.ec2.dev_credential
}

output "elk_private_ip" {
  value = module.ec2.elk_private_ip
}

output "victim_private_ip" {
  value = module.ec2.victim_private_ip
}

output "victim_credential" {
  value = module.ec2.victim_credential
}
output "victim_admin_credential" {
  value = module.ec2.victim_admin_credential
}

output "attacker_private_ip" {
  value = module.ec2.attacker_private_ip
}
