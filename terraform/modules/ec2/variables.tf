variable "project_name" {
  type = string
  description = "プロジェクト名"
}

variable "vpc_id" {
  type = string
  description = "VPCのID"
}

variable "public_subnet_id" {
  type = string
  description = "PublicサブネットのID"
}

variable "private_subnet_id" {
  type = string
  description = "PrivateサブネットのID"
}

variable "my_ip" {
  type = string
  description = "Terraform実行時のグローバルIP 例：0.0.0.0/32"
}
