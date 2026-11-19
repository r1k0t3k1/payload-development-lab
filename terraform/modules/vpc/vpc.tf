resource "aws_vpc" "lab" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "lab-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.lab.id 
  cidr_block = "192.168.1.0/24" 
  map_public_ip_on_launch = true
  tags = { Name = "lab-public" }
}

resource "aws_subnet" "private" {
  vpc_id = aws_vpc.lab.id 
  cidr_block = "192.168.2.0/24" 
  tags = { Name = "lab-private" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.lab.id
  tags = { Name = "igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "lab-public-route-table" }
}

resource "aws_route_table_association" "public" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
