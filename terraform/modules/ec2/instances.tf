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
  filename        = "${path.root}/keys/dev_id_ed25519"
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
  filename        = "${path.root}/keys/elk_id_ed25519"
  file_permission = "0600"
}


########## ELK ###########
resource "aws_instance" "elk" {
  ami                         = "ami-0f122bd24f21fd99f" # Ubuntu Server 26.04 LTS
  instance_type               = "t3.xlarge"
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids = [
    aws_security_group.lab_internal.id,
    aws_security_group.elk.id,
  ]
  key_name                    = aws_key_pair.elk.key_name
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
      $pw  = ConvertTo-SecureString 'Password123!' -AsPlainText -Force
      New-LocalUser -Name 'victim' -Password $pw -PasswordNeverExpires -AccountNeverExpires
      Add-LocalGroupMember -Group 'Remote Management Users' -Member 'victim'
      $pwa = ConvertTo-SecureString 'Password123!' -AsPlainText -Force
      New-LocalUser -Name 'victim_admin' -Password $pwa -PasswordNeverExpires -AccountNeverExpires
      Add-LocalGroupMember -Group 'Administrators' -Member 'victim_admin'

      Enable-PSRemoting -Force -SkipNetworkProfileCheck
      Set-Service -Name WinRM -StartupType Automatic
      Start-Service WinRM

      Set-Item -Path WSMan:\localhost\Service\Auth\Basic       -Value $true
      Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true

      $cert = New-SelfSignedCertificate -DnsName "victim" -CertStoreLocation Cert:\LocalMachine\My
      New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $cert.Thumbprint -Force

      New-NetFirewallRule -DisplayName "WinRM HTTP"  -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow
      New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow
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
    description = "Allow WinRM from dev only"
    from_port = 5985
    to_port   = 5986
    protocol  = "tcp" 
    security_groups = [aws_security_group.dev.id]
  }

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
  filename        = "${path.root}/keys/attacker_id_ed25519"
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
