provider "aws" {
  region = "us-east-1"
}

variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"
}

variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "IsaqueBraga"
}

resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096  # ALTEREI O NÚMERO DE BITS PARA 4096 PARA MELHORAR A SEGURANÇA DA CHAVE.
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"
  }
}

resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"
  }
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-igw"
  }
}

resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table"
  }
}

resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table_association"
  }
}

resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  description = "Permitir SSH e HTTP de qualquer lugar e todo o tráfego de saída"
  vpc_id      = aws_vpc.main_vpc.id

  # Regras de entrada
  ingress {
    description      = "Allow SSH from specific IP"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["177.12.220.206/32"]  # ALTEREI PARA PERMITIR SSH APENAS A PARTIR DE UM IP ESPECÍFICO (O MEU, POR EXEMPLO).
  }

  ingress {
    description      = "Allow HTTP for Nginx"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Regras de saída
  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-sg"
  }
}

# ALTEREI O FILTRO PARA LIMITAR A VERSÃO DO AMI AO DEBIAN 12 MAIS RECENTE.
data "aws_ami" "debian12" {
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["679593333241"]
}

resource "aws_instance" "debian_ec2" {
  ami             = data.aws_ami.debian12.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.main_subnet.id
  key_name        = aws_key_pair.ec2_key_pair.key_name
  security_groups = [aws_security_group.main_sg.name]

  associate_public_ip_address = true

  # AUMENTEI O TAMANHO DO DISCO PARA 30GB PARA SUPORTAR MAIS APLICAÇÕES.
  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"  # ALTEREI PARA GP3 PARA MELHOR PERFORMANCE.
    delete_on_termination = true
  }

  # CONFIGUREI O USER DATA PARA INSTALAR E INICIAR O NGINX AUTOMATICAMENTE.
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              apt-get install -y nginx  # INSTALA O NGINX.
              systemctl start nginx     # INICIA O NGINX.
              systemctl enable nginx    # CONFIGURA O NGINX PARA INICIAR NO BOOT.
              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}

output "private_key" {
  description = "Chave privada para acessar a instância EC2"
  value       = tls_private_key.ec2_key.private_key_pem
  sensitive   = true
}

output "ec2_public_ip" {
  description = "Endereço IP público da instância EC2"
  value       = aws_instance.debian_ec2.public_ip
}

# ADICIONEI UM OUTPUT PARA EXIBIR A VERSÃO DO AMI SELECIONADO.
output "ami_version" {
  description = "AMI utilizada para criar a instância"
  value       = data.aws_ami.debian12.id
}

# ADICIONEI REGRAS PARA MONITORAMENTO DO LOG DO NGINX.
resource "aws_cloudwatch_log_group" "nginx_log_group" {
  name              = "/aws/ec2/${var.projeto}-${var.candidato}-nginx"
  retention_in_days = 7  # ALTEREI PARA MANTER OS LOGS POR 7 DIAS.
}

resource "aws_cloudwatch_log_stream" "nginx_access_logs" {
  log_group_name = aws_cloudwatch_log_group.nginx_log_group.name
  name           = "nginx-access"
}

resource "aws_cloudwatch_log_stream" "nginx_error_logs" {
  log_group_name = aws_cloudwatch_log_group.nginx_log_group.name
  name           = "nginx-error"
}
