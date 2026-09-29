# My own VPC instead of using the default one, so I know exactly what is in it.
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "secure-baseline-vpc"
  }
}

# One public subnet. The instance needs a public IP to reach the SSM service
# because I'm not paying for a NAT gateway or VPC endpoints.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "secure-baseline-public"
  }
}

# Internet gateway - lets resources in the public subnet talk to the internet.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "secure-baseline-igw"
  }
}

# Route table that sends all non-local traffic to the internet gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "secure-baseline-public-rt"
  }
}

# Attach the route table to the public subnet.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Every VPC comes with a default security group that allows all traffic between its members.
# Taking it over in Terraform with no rules removes all of them, so nothing can use it by accident.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "secure-baseline-default-sg-locked"
  }
}
