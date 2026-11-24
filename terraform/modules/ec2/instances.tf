########## DEV ##########
resource "aws_instance" "dev" {
  ami = "ami-0cf5a6e5ce505aded" # Windows Server 2025 DataCenter
  instance_type = "t3.large"
  subnet_id = var.public_subnet_id
  vpc_security_group_ids = [
    aws_security_group.dev.id,
  ]

  user_data = <<-EOF
    <powershell>
      net user '${local.dev_username}' '${local.password}' /add /expires:never
      net localgroup Administrators '${local.dev_username}' /add
    
      Start-Service sshd
      Set-Service -Name sshd -StartupType 'Automatic'
      Set-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -Profile Any
      $ak = 'C:\ProgramData\ssh\administrators_authorized_keys'
      Set-Content -Encoding Ascii -Path $ak -Value '${tls_private_key.dev.public_key_openssh}'
      icacls $ak /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"

      mkdir C:\Users\${local.dev_username}\.ssh
      Set-Content -Encoding Ascii -Path 'C:\Users\${local.dev_username}\.ssh\dev-to-elk_id_ed25519' -Value '${tls_private_key.elk.private_key_openssh}'
      icacls C:\Users\${local.dev_username}\.ssh\dev-to-elk_id_ed25519 /inheritance:r /grant:r "${local.dev_username}:R"

      Set-Content -Encoding Ascii -Path 'C:\Users\${local.dev_username}\.ssh\dev-to-attacker_id_ed25519' -Value '${tls_private_key.attacker.private_key_openssh}'
      icacls C:\Users\${local.dev_username}\.ssh\dev-to-attacker_id_ed25519 /inheritance:r /grant:r "${local.dev_username}:R"

      Set-Content -Encoding Ascii -Path 'C:\Users\${local.dev_username}\.ssh\dev-to-victim_admin_id_ed25519' -Value '${tls_private_key.victim_admin.private_key_openssh}'
      icacls C:\Users\${local.dev_username}\.ssh\dev-to-victim_admin_id_ed25519 /inheritance:r /grant:r "${local.dev_username}:R"

      Set-Item WSMan:\localhost\Client\TrustedHosts -Value ${aws_instance.victim.private_ip} -Force
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
  
  ingress {
    description = "Allow SSH from my ip only"
    from_port = 22
    to_port   = 22
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

resource "tls_private_key" "dev" {
  algorithm = "ED25519" 
}

resource "aws_key_pair" "dev" {
  key_name   = "${var.project_name}-key-dev"
  public_key = tls_private_key.dev.public_key_openssh
}

resource "local_file" "dev" {
  content         = tls_private_key.dev.private_key_openssh
  filename        = "${path.root}/keys/${local.dev_sshkey_filename}"
  file_permission = "0600"
}

resource "tls_private_key" "elk" {
  algorithm = "ED25519" 
}

resource "aws_key_pair" "elk" {
  key_name   = "${var.project_name}-key-elk"
  public_key = tls_private_key.elk.public_key_openssh
}

resource "local_file" "elk" {
  content         = tls_private_key.elk.private_key_openssh
  filename        = "${path.root}/keys/${local.elk_sshkey_filename}"
  file_permission = "0600"
}


########## ELK ###########
resource "aws_instance" "elk" {
  ami                         = "ami-0f122bd24f21fd99f" # Ubuntu Server 26.04 LTS
  instance_type               = "t3.xlarge"
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.elk.id]
  key_name                    = aws_key_pair.elk.key_name
  user_data_replace_on_change = true
  
  root_block_device {
    volume_type = "gp3"
    volume_size = "100"
  }

  user_data = <<-EOF
  EOF

  tags = {
    "Name" = "${var.project_name}-ec2-elk"
  }
}

resource "aws_security_group" "elk" {
  name = "${var.project_name}-sg-elk"
  vpc_id = var.vpc_id
  
  ingress { # 内向きは内部+DEVからのみに制限
    description     = "from DEV (SSH/Kibana/ES)"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.dev.id]
  }

  egress { # ElasticeSearch用に外向きは許可
    description     = "internet outbound"
    from_port       = 0
    to_port         = 0
    protocol        = "-1" 
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


########## VICTIM ###########
resource "aws_instance" "victim" {
  ami = "ami-0cf5a6e5ce505aded" # Windows Server 2025 DataCenter
  instance_type               = "t3.large"
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [
    aws_security_group.lab_internal.id,
    aws_security_group.victim.id,
  ]
  user_data_replace_on_change = true

  user_data = <<-EOF
    <powershell>
      $pw  = ConvertTo-SecureString '${local.password}' -AsPlainText -Force
      New-LocalUser -Name '${local.victim_username}' -Password $pw -PasswordNeverExpires -AccountNeverExpires
      Add-LocalGroupMember -Group 'Remote Management Users' -Member '${local.victim_username}'

      $pwa = ConvertTo-SecureString '${local.password}' -AsPlainText -Force
      New-LocalUser -Name '${local.victim_admin_username}' -Password $pwa -PasswordNeverExpires -AccountNeverExpires
      Add-LocalGroupMember -Group 'Administrators' -Member '${local.victim_admin_username}'

      $ak = 'C:\ProgramData\ssh\administrators_authorized_keys'
      Set-Content -Encoding Ascii -Path $ak -Value '${tls_private_key.victim_admin.public_key_openssh}'
      icacls $ak /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"

      $k = C:\Users\${local.victim_username}\.ssh\
      Set-Content -Encoding Ascii -Path $k -Value '${tls_private_key.victim.public_key_openssh}'
    
      Start-Service sshd
      Set-Service -Name sshd -StartupType 'Automatic'
      Set-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -Profile Any
    </powershell>
  EOF

  tags = {
    "Name" = "${var.project_name}-ec2-victim"
  }
}


resource "aws_security_group" "victim" {
  name = "${var.project_name}-sg-victim"
  vpc_id = var.vpc_id
  
  ingress {
    description = "Allow SSH from dev only"
    from_port = 22
    to_port   = 22
    protocol  = "tcp" 
    security_groups = [aws_security_group.dev.id]
  }

}

resource "tls_private_key" "victim" {
  algorithm = "ED25519" 
}

resource "aws_key_pair" "victim" {
  key_name   = "${var.project_name}-key-victim"
  public_key = tls_private_key.victim.public_key_openssh
}

resource "local_file" "victim" {
  content         = tls_private_key.victim.private_key_openssh
  filename        = "${path.root}/keys/${local.victim_sshkey_filename}"
  file_permission = "0600"
}

resource "tls_private_key" "victim_admin" {
  algorithm = "ED25519" 
}

resource "aws_key_pair" "victim_admin" {
  key_name   = "${var.project_name}-key-victim-admin"
  public_key = tls_private_key.victim_admin.public_key_openssh
}

resource "local_file" "victim_admin" {
  content         = tls_private_key.victim_admin.private_key_openssh
  filename        = "${path.root}/keys/${local.victim_admin_sshkey_filename}"
  file_permission = "0600"
}

########## ATTACKER ##########
resource "aws_instance" "attacker" {
  ami                         = "ami-0f122bd24f21fd99f" # Ubuntu Server 26.04 LTS
  instance_type               = "t3.small"
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [
    aws_security_group.lab_internal.id,
    aws_security_group.attacker.id,
  ]
  key_name                    = aws_key_pair.attacker.key_name
  user_data_replace_on_change = true

  user_data = <<-EOF
  EOF

  tags = {
    "Name" = "${var.project_name}-ec2-attacker"
  }
}

resource "aws_security_group" "attacker" {
  name = "${var.project_name}-sg-attacker"
  vpc_id = var.vpc_id
  
  ingress {
    description = "Allow SSH from dev only"
    from_port = 22
    to_port   = 22
    protocol  = "tcp" 
    security_groups = [aws_security_group.dev.id]
  }
}

resource "tls_private_key" "attacker" {
  algorithm = "ED25519" 
}

resource "aws_key_pair" "attacker" {
  key_name   = "${var.project_name}-key-attacker"
  public_key = tls_private_key.attacker.public_key_openssh
}

resource "local_file" "attacker" {
  content         = tls_private_key.attacker.private_key_openssh
  filename        = "${path.root}/keys/${local.attacker_sshkey_filename}"
  file_permission = "0600"
}

########## Lab internal SG ##########
resource "aws_security_group" "lab_internal" {
  name = "${var.project_name}-sg-internal"
  vpc_id = var.vpc_id

  ingress {
    description = "Allow all from lab members"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true 
  }

  egress {
    description = "Allow all to lab members"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true 
  }
}
