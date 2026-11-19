variable "region" {
  default = "ap-northeast-1"
}

variable "project_name" {
  type = string
  default = "payload-development-lab"
}

data "http" "global_ip" {
  url = "https://ifconfig.me/ip" 
}

variable "password" {
  type = string
}
