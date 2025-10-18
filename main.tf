resource "aws_vpc" "tf_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Exercise"
  }
}

resource "aws_subnet" "tf_vpc_public_subnet" {
  vpc_id                  = aws_vpc.tf_vpc.id
  cidr_block              = "10.0.128.0/17"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "Exercise-public"
  }
}

resource "aws_subnet" "tf_vpc_private_subnet" {
  vpc_id            = aws_vpc.tf_vpc.id
  cidr_block        = "10.0.0.0/17"
  availability_zone = "us-east-1b"
  tags = {
    Name = "Exercise-private"
  }
}

resource "aws_internet_gateway" "tf_igw" {
  vpc_id = aws_vpc.tf_vpc.id
  tags = {
    Name = "Exercise-igw"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "tf_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.tf_vpc_public_subnet.id

  tags = {
    Name = "nat-gateway"
  }
}

resource "aws_route_table" "tf_public_rt" {
  vpc_id = aws_vpc.tf_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf_igw.id
  }
  tags = {
    Name = "Exercise-public-rt"
  }
}

resource "aws_route_table" "tf_private_rt" {
  vpc_id = aws_vpc.tf_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.tf_nat.id
  }

  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "tf_public_rtassoc" {
  subnet_id      = aws_subnet.tf_vpc_public_subnet.id
  route_table_id = aws_route_table.tf_public_rt.id
}

resource "aws_route_table_association" "tf_private_assoc" {
  subnet_id      = aws_subnet.tf_vpc_private_subnet.id
  route_table_id = aws_route_table.tf_private_rt.id
}

resource "aws_security_group" "tf_sg_ec2instance" {
  name        = "tf_sg_instance"
  description = "SG for EC2 instance"
  vpc_id      = aws_vpc.tf_vpc.id

  ingress {
    description = "Allow SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "tf_sg_efs" {
  name        = "tf_sg_efs"
  description = "SG for efs"
  vpc_id      = aws_vpc.tf_vpc.id

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "tf_sg_lambda" {
  name        = "tf_sg_lambda"
  description = "SG for lambda"
  vpc_id      = aws_vpc.tf_vpc.id

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group_rule" "ingress_allow_lambda_to_ec2" {
  description              = "ingress - Allow Lambda to EC2"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tf_sg_lambda.id
  security_group_id        = aws_security_group.tf_sg_ec2instance.id
}

resource "aws_security_group_rule" "egress_allow_ec2_to_efs" {
  description              = "egress - Allow EC2 to EFS"
  type                     = "egress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tf_sg_efs.id
  security_group_id        = aws_security_group.tf_sg_ec2instance.id
}

resource "aws_security_group_rule" "ingress_allow_ec2_to_efs_nfs" {
  description              = "ingress - Allow Lambda to EC2"
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tf_sg_ec2instance.id
  security_group_id        = aws_security_group.tf_sg_efs.id
}

resource "aws_security_group_rule" "ingress_allow_lambda_to_efs_nfs" {
  description              = "ingress - Allow Lambda to EC2"
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tf_sg_lambda.id
  security_group_id        = aws_security_group.tf_sg_efs.id
}

resource "aws_security_group_rule" "egress_allow_ec2_to_lambda" {
  description              = "egress - Allow EC2 to Lambda"
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tf_sg_ec2instance.id
  security_group_id        = aws_security_group.tf_sg_lambda.id
}

resource "aws_key_pair" "tf_auth" {
  key_name   = "tfkey"
  public_key = file("~/.ssh/tfkey.pub")
}

resource "aws_efs_file_system" "tf_efs" {
  creation_token = "ef_efs"
  encrypted      = true
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
}

resource "aws_efs_mount_target" "efs_mt_a" {
  file_system_id  = aws_efs_file_system.tf_efs.id
  subnet_id       = aws_subnet.tf_vpc_public_subnet.id
  security_groups = [aws_security_group.tf_sg_efs.id]
}
resource "aws_efs_mount_target" "efs_mt_b" {
  file_system_id  = aws_efs_file_system.tf_efs.id
  subnet_id       = aws_subnet.tf_vpc_private_subnet.id
  security_groups = [aws_security_group.tf_sg_efs.id]
}

resource "aws_instance" "tf_node" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.tf_ami.id
  key_name               = aws_key_pair.tf_auth.id
  vpc_security_group_ids = [aws_security_group.tf_sg_ec2instance.id]
  subnet_id              = aws_subnet.tf_vpc_public_subnet.id

  user_data = <<-EOF
      #!/bin/bash
      yum install -y amazon-efs-utils
      mkdir -p /mnt/efs
      mount -t efs -o tls,accesspoint=${aws_efs_access_point.access_point_lambda.id} ${aws_efs_file_system.tf_efs.id}:/ /mnt/efs
      echo "${aws_efs_file_system.tf_efs.id}:/ /mnt/efs efs defaults,_netdev 0 0" >> /etc/fsta
    EOF

  tags = {
    Name = "tf-node"
  }
}

resource "aws_efs_access_point" "access_point_lambda" {
  file_system_id = aws_efs_file_system.tf_efs.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/mnt/efs"

    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0777"
    }
  }

  tags = {
    Name = "lambda-efs-access-point"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-efs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_ec2_access" {
  name = "lambda-vpc-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_efs_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientFullAccess"
}

resource "aws_lambda_function" "lambda_with_efs" {
  function_name = "lambda-with-efs"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  timeout       = 30

  filename         = "${path.module}/lambda_function.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_function.zip")

  vpc_config {
    subnet_ids         = [aws_subnet.tf_vpc_private_subnet.id, aws_subnet.tf_vpc_public_subnet.id]
    security_group_ids = [aws_security_group.tf_sg_lambda.id]
  }

  file_system_config {
    arn              = aws_efs_access_point.access_point_lambda.arn
    local_mount_path = "/mnt/efs"
  }

  environment {
    variables = {
      MOUNT_PATH = "/mnt/efs"
    }
  }
}