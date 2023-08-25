provider "aws" {
  region = "us-east-2"
}

resource "aws_vpc" "prometheus_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prometheus_vpc.id

  tags = {
    Name = "prometheus_ig"
  }
}

resource "aws_route_table" "internet-gw" {
  vpc_id = aws_vpc.prometheus_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_subnet" "prometheus_subnet" {
  vpc_id     = aws_vpc.prometheus_vpc.id
  cidr_block = "10.0.10.0/24"
}

resource "aws_route_table_association" "route_table_management" {
  subnet_id      = aws_subnet.prometheus_subnet.id
  route_table_id = aws_route_table.internet-gw.id
}

resource "aws_security_group" "prometheus_sg" {
  name        = "prometheus-sg"
  description = "Security group for Prometheus cluster"
  vpc_id      = aws_vpc.prometheus_vpc.id

  # Inbound rules for Prometheus
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Adjust this to limit access if needed
  }

  # Inbound rules for nginx
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Adjust this to limit access if needed
  }

  # Inbound rules for SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Adjust this to limit access if needed
  }

  # Allow all Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "prometheus_server_primary" {
  ami                         = "ami-08fdd91d87f63bb09" # Ubuntu Server 22.04 LTS 64-bit Arm for us-east-2
  instance_type               = "t4g.nano"
  subnet_id                   = aws_subnet.prometheus_subnet.id
  vpc_security_group_ids      = [aws_security_group.prometheus_sg.id]
  key_name                    = "prometheus_key_pair"
  associate_public_ip_address = true
  depends_on                  = [aws_internet_gateway.gw]
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = 0.016
    }
  }
  tags = {
    Name = "prometheus-primary"
  }
}

resource "aws_instance" "prometheus_server_secondary" {
  ami                         = "ami-08fdd91d87f63bb09"
  instance_type               = "t4g.nano"
  subnet_id                   = aws_subnet.prometheus_subnet.id
  vpc_security_group_ids      = [aws_security_group.prometheus_sg.id]
  key_name                    = "prometheus_key_pair"
  associate_public_ip_address = true
  depends_on                  = [aws_internet_gateway.gw]
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = 0.016
    }
  }
  tags = {
    Name = "prometheus-secondary"
  }
}


output "prometheus_server_primary_public_ip" {
  description = "Public IP address of the primary Prometheus server"
  value       = aws_instance.prometheus_server_primary.public_ip
}

output "prometheus_server_secondary_public_ip" {
  description = "Public IP address of the secondary Prometheus server"
  value       = aws_instance.prometheus_server_secondary.public_ip
}
