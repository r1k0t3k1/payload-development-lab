locals {
  my_ip = "${chomp(data.http.global_ip.response_body)}/32"
}
