# Minimal VPC — exists only to satisfy Aurora's DB subnet group requirement.
# No internet gateway, no NAT: nothing needs outbound internet access from
# inside this VPC. The API Lambda and Bedrock Knowledge Bases reach Aurora
# over the RDS Data API (HTTP, outside the VPC) — see ADR-008.

resource "aws_vpc" "main" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "doclens-${var.environment}"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "db" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "doclens-db-${var.environment}-${count.index}"
  }
}

resource "aws_db_subnet_group" "aurora" {
  name       = "doclens-aurora-${var.environment}"
  subnet_ids = aws_subnet.db[*].id
}

resource "aws_security_group" "aurora" {
  name        = "doclens-aurora-${var.environment}"
  description = "Aurora cluster security group — Data API access does not require inbound rules from Lambda."
  vpc_id      = aws_vpc.main.id

  # No ingress rules: the RDS Data API is invoked over the AWS API plane,
  # not a direct network connection into the VPC. This SG exists because
  # the cluster resource requires one; it stays closed.

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
