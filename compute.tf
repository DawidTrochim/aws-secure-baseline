# Look up the latest Amazon Linux 2023 AMI so I don't have to hardcode an AMI ID.
# AL2023 already has the SSM agent installed.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# IAM role the EC2 instance uses. The trust policy says only the EC2 service can assume it.
resource "aws_iam_role" "ec2_ssm" {
  name = "secure-baseline-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# AWS managed policy that lets the instance register with Systems Manager,
# which is what makes Session Manager work without SSH.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# An instance profile is the "container" that attaches the role to the EC2 instance.
resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "secure-baseline-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name
}

# Security group with no inbound rules at all - nothing on the internet can connect in.
# Outbound is allowed so the SSM agent can reach AWS.
resource "aws_security_group" "ec2" {
  name        = "secure-baseline-ec2-sg"
  description = "No inbound access. Outbound only, for SSM."
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "secure-baseline-ec2-sg"
  }
}

# The EC2 instance. No key pair, so there is no SSH key to lose - I connect with Session Manager.
resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name

  # Force IMDSv2. v1 answers any plain GET request, so an SSRF bug in an app on the box
  # could be used to steal the role's credentials. v2 needs a session token first.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Encrypt the root disk. Uses the AWS managed EBS key, which is free.
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 8
  }

  tags = {
    Name = "secure-baseline-app"
  }
}
