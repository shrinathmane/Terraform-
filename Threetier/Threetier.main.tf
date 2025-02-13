terraform {
  required_version = "~> 1.1"
  required_providers {
    aws = {
      version = "~>3.1"
    }
  }
}
provider "aws" {
  region     = var.my_region
  access_key = var.access_key
  secret_key = var.secret_key
}
resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
   tags = {
    Name = "my-cust-vpc"
  }
}
resource "aws_internet_gateway" "my-igw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "my-igw"
  }
}
resource "aws_subnet" "websubnet" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "websubnet"
  }
}
resource "aws_subnet" "appsubnet" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "appsubnet"
  }
}
resource "aws_subnet" "dbsubnet" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.2.0/24"
 availability_zone = "ap-south-1c"
  tags = {
    Name = "dbsubnet"
  }
}
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-igw.id
  }
   tags = {
    Name = "public-rt"
  }
}
resource "aws_route_table" "pvt-rt" {
  vpc_id = aws_vpc.myvpc.id
   tags = {
    Name = "pvt-rt"
  }
}
resource "aws_route_table_association" "web-assoc" {
  subnet_id      = aws_subnet.websubnet.id
  route_table_id = aws_route_table.public-rt.id
}
resource "aws_route_table_association" "app-assoc" {
  subnet_id      = aws_subnet.appsubnet.id
  route_table_id = aws_route_table.pvt-rt.id
}
resource "aws_route_table_association" "db-assoc" {
  subnet_id      = aws_subnet.dbsubnet.id
  route_table_id = aws_route_table.pvt-rt.id
}
resource "aws_security_group" "websg" {
  name   = "web-sg"
  vpc_id = aws_vpc.myvpc.id


  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
  }
}
resource "aws_security_group" "appsg" {
  name   = "app-sg"
  vpc_id = aws_vpc.myvpc.id


  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    cidr_blocks = ["10.0.0.0/24"]
    from_port   = 9000
    protocol    = "tcp"
    to_port     = 9000
  }
}
resource "aws_security_group" "dbsg" {
  name   = "db-sg"
  vpc_id = aws_vpc.myvpc.id


  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  ingress {
    cidr_blocks = ["10.0.1.0/24"]
    from_port   = 3306
    protocol    = "tcp"
    to_port     = 3306
  }
}
resource "aws_instance" "web" {
subnet_id = aws_subnet.websubnet.id
  ami                    = var.my_ami
  instance_type          = "t2.micro"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.websg.id]
  tags = {
    Name     = "webinstance"
    key_name = "mumbai"
  }
}
resource "aws_instance" "app" {
subnet_id = aws_subnet.appsubnet.id
  ami                    = var.my_ami
  instance_type          = "t2.micro"
  associate_public_ip_address = false
  vpc_security_group_ids = [aws_security_group.appsg.id]
  tags = {
    Name     = "appinstance"
    key_name = "mumbai"
  }
}
resource "aws_db_instance" "my-rds" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = "admin"
  password             = "Pass1234"
  vpc_security_group_ids = [aws_security_group.dbsg.id]
  db_subnet_group_name = aws_db_subnet_group.mysubnetgp.name
  skip_final_snapshot  = true
}
resource "aws_db_subnet_group" "mysubnetgp" {
  name       = "mysubnetgp"
  subnet_ids = [aws_subnet.appsubnet.id, aws_subnet.dbsubnet.id]

  tags = {
    Name = "My DB subnet group"
  }
}
resource "aws_key_pair" "terraf1-key-pair" {
  key_name   = "terraf1-key-pair"
  public_key = tls_private_key.rsa.public_key_openssh
}
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "tf-key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "terraf1-key-pair"
}
