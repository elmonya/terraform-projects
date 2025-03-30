terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.88.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# Create VPC
resource "aws_vpc" "multicast_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "MulticastVPC"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.multicast_vpc.id

  tags = {
    Name = "MyInternetGateway"
  }
}

# Create Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.multicast_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

# Create SSH Key Pair
resource "aws_key_pair" "ssh_key" {
  key_name   = "id_rsa"
  public_key = file("/home/serkas/.ssh/id_rsa.pub")  
}

# Create Public Subnet
resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.multicast_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true  # Enable automatic public IP assignment
}

# Security Group for SSH Access
resource "aws_security_group" "ssh_sg" {
  name        = "ssh-security-group"
  vpc_id      = aws_vpc.multicast_vpc.id
  description = "Allow SSH access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Consider restricting to your IP
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Consider restricting to your IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SSH Security Group"
  }
}

# VM 1
resource "aws_instance" "vm_instance_1" {
  ami                         = "ami-09a9858973b288bdd"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet_a.id
  vpc_security_group_ids      = [aws_security_group.ssh_sg.id]
  key_name                    = aws_key_pair.ssh_key.key_name
  associate_public_ip_address = true

  tags = {
    Name = "VM-1"
  }
}

# VM 2
resource "aws_instance" "vm_instance_2" {
  ami                         = "ami-09a9858973b288bdd"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet_a.id
  vpc_security_group_ids      = [aws_security_group.ssh_sg.id]
  key_name                    = aws_key_pair.ssh_key.key_name
  associate_public_ip_address = true

  tags = {
    Name = "VM-2"
  }
}

# Output Public IPs
output "instance_ips" {
  value = {
    VM1_IP = aws_instance.vm_instance_1.public_ip
    VM2_IP = aws_instance.vm_instance_2.public_ip
  }
}
