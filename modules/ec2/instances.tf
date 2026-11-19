########## DEV ##########
resource "aws_instance" "dev" {
  ami = "ami-0cf5a6e5ce505aded" # Windows Server 2025 DataCenter
  instance_type = "t3.large"
  subnet_id = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.dev.id]

  user_data = <<-EOF
    <powershell>
      net user '${local.username}' '${var.password}' /add /expires:never
      net localgroup Administrators '${local.username}' /add
      mkdir C:\Users\${local.username}\.ssh
      Set-Content -Encoding Ascii -Path 'C:\Users\${local.username}\.ssh\dev-to-elk_id_ed25519' -Value '${tls_private_key.dev_to_elk.private_key_openssh}'
      icacls C:\Users\${local.username}\.ssh\dev-to-elk_id_ed25519 /inheritance:r /grant:r "${local.username}:R"
    </powershell>
  EOF

  user_data_replace_on_change = true

  tags = {
    "Name" = "${var.project_name}-ec2-dev"
  }
}

resource "aws_security_group" "dev" {
  name = "${var.project_name}-sg-dev"
  vpc_id = var.vpc_id
  
  ingress {
    description = "Allow RDP from my ip only"
    from_port = 3389
    to_port   = 3389
    protocol  = "tcp" 
    cidr_blocks = [var.my_ip]
  }
  
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1" 
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "tls_private_key" "dev_to_elk" {
  algorithm = "ED25519" 
}

resource "aws_key_pair" "dev_to_elk" {
  key_name   = "${var.project_name}-dev-to-elk"
  public_key = tls_private_key.dev_to_elk.public_key_openssh
}


########## ELK ###########
resource "aws_instance" "elk" {
  ami                         = "ami-0f122bd24f21fd99f" # Ubuntu Server 26.04 LTS
  instance_type               = "t3.xlarge"
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.elk.id]
  key_name                    = aws_key_pair.dev_to_elk.key_name
  user_data_replace_on_change = true

  user_data = <<-EOF
  EOF

  tags = {
    "Name" = "${var.project_name}-ec2-elk"
  }
}

resource "aws_security_group" "elk" {
  name = "${var.project_name}-sg-elk"
  vpc_id = var.vpc_id
  
  ingress {
    description = "Allow SSH from dev only"
    from_port = 22
    to_port   = 22
    protocol  = "tcp" 
    security_groups = [aws_security_group.dev.id]
  }
}


