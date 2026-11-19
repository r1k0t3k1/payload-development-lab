output "instance_public_ip" {
  type        = string
  description = "The ip address of the public interface"
  value = aws_instance.dev.public_ip
}
